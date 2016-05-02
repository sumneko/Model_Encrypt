require 'luabind'
require 'filesystem'

local temp_dir    = fs.path('temp')
local encrypt_name = '%s体'

local function extract(map, filename, dir)
	-- 尝试导出文件
	if not map:extract(filename, dir) then
		return nil
	end
	return io.load(dir, 'rb')
end

local encrypt_list = {}
local function encrypt_model(map, name, reason)
	if encrypt_list[name] then
		encrypt_list[name] = reason
		return true
	end
	local new_name = encrypt_name:format(name)
	if map:rename(name .. '.mdl', new_name .. '.mdl') or map:rename(name .. '.mdx', new_name .. '.mdx') then
		encrypt_list[name] = reason
		return true
	end
	return false
end

local function create_log(dir)
	local list = {}
	for name, reason in pairs(encrypt_list) do
		table.insert(list, name)
	end
	table.sort(list)
	for i, name in ipairs(list) do
		list[i] = ('[%s]:	%s'):format(encrypt_list[name], name)
	end
	local success = '加密完成,共加密 ' .. #list .. ' 个模型,用时 ' .. os.clock() .. ' 秒.'
	table.insert(list, 1, success)
	table.insert(list, 2, '若出现模型消失或有模型漏加密的情况,请联系最萌小汐(QQ76196625)')
	table.insert(list, 3, '加密了以下模型,请检查是否有缺失')
	io.save(dir / '模型加密报告.txt', table.concat(list, '\n'))
	print('[成功]	' .. success)
	print('[成功]	查看 "模型加密报告.txt" 了解更多信息')
end

local function read_jass(map)
	local jass = extract(map, 'scripts\\war3map.j', temp_dir / 'war3map.j') or extract(map, 'war3map.j', temp_dir / 'war3map.j')
	if not jass then
		print '[错误]	没有找到脚本'
		return
	end
	
	local new_jass = jass:gsub('([^\\]")(%C*)(%.[mM][dD][lLxX]")', function(str1, name, str2)
		if encrypt_model(map, name:gsub([[\\]], [[\]]), 'war3map.j') then
			return str1 .. encrypt_name:format(name) .. str2
		end
	end)
	
	io.save(temp_dir / 'war3map.j', new_jass)

	if map:remove 'script\\war3map.j' then
		map:import('scripts\\war3map.j', temp_dir / 'war3map.j')
	end
	if map:remove 'war3map.j' then
		map:import('war3map.j', temp_dir / 'war3map.j')
	end
end

local function read_slk(map, name)
	local slk = extract(map, 'units\\' .. name, temp_dir / name)
	if not slk then
		return
	end

	local new_slk = slk:gsub('(")(%C*)(%.[mM][dD][lLxX]")', function(str1, filename, str2)
		if encrypt_model(map, filename, name) then
			return str1 .. encrypt_name:format(filename) .. str2
		end
	end)
	
	io.save(temp_dir / name, new_slk)
	
	map:import('units\\' .. name, temp_dir / name)
end

local function read_w3x(map, name)
	local obj = extract(map, name, temp_dir / name)
	if not obj then
		return
	end

	local new_obj = obj:gsub('([\0,])(%C*)(%.[mM][dD][lLxX][\0,])', function(str1, filename, str2)
		if encrypt_model(map, filename, name) then
			return str1 .. encrypt_name:format(filename) .. str2
		end
	end)

	io.save(temp_dir / name, new_obj)

	map:import(name, temp_dir / name)
end

local function read_lua(map)
	local listfile = extract(map, '(listfile)', temp_dir / '(listfile)')
	if not listfile then
		return
	end

	for dir in listfile:gmatch '%C+' do
		if dir:sub(-4, -1) == '.lua' then
			local lua = extract(map, dir, temp_dir / 'temp.lua')
			if lua then
				new_lua = lua:gsub([[([^\]['"])(%C*)(%.[mM][dD][lLxX]['"])]], function(str1, name, str2)
					if encrypt_model(map, name:gsub([[\\]], [[\]]), dir) then
						return str1 .. encrypt_name:format(name) .. str2
					end
				end)
				new_lua = new_lua:gsub([[([^\]%[%[)(%C*)(%.[mM][dD][lLxX]%]%])]], function(str1, name, str2)
					if encrypt_model(map, name, dir) then
						return str1 .. encrypt_name:format(name) .. str2
					end
				end)
				
				io.save(temp_dir / 'temp.lua', new_lua)
	
				map:import(dir, temp_dir / 'temp.lua')
			end
		end
	end
end

local function fix_head(dir)
	local map = io.load(dir)
	if map then
		local content = map:sub(1, 516) .. '\32\0\0\0' .. map:sub(521, -1)
		io.save(dir, content)
	end
end

local function main()
	--添加require搜寻路径
	package.path = package.path .. ';' .. arg[1] .. 'src\\?.lua'
	package.cpath = package.cpath .. ';' .. arg[1] .. 'build\\?.dll'
	require 'utility'
	require 'localization'

	-- 检查参数 arg[1]为地图, arg[2]为本地路径
	if #arg < 2 then
		print '[错误]	请将要加密的地图拖动到bat中'
		return
	end

	-- 保存路径
	local root_dir   = fs.path(ansi_to_utf8(arg[1]))
	local input_dir  = fs.path(ansi_to_utf8(arg[2]))
	
	fs.set_current_path(root_dir)

	local output_dir = input_dir:parent_path() / fs.path('加密过模型的' .. input_dir:filename():string())

	-- 创建一个临时目录
	fs.create_directories(temp_dir)
	-- 复制一张地图出来
	local success = pcall(fs.copy_file, input_dir, output_dir, true)
	if not success then
		print '[错误]	地图创建失败,可能是地图文件被占用了'
		return
	end
	-- 修复地图的字头(简单修复)
	fix_head(output_dir)

	-- 用storm打开复制出来的地图
	local map = mpq_open(output_dir)
	if not map then
		print '[错误]	地图打开失败,可能是使用了特殊的加密手段,或者根本不是地图'
		fs.remove(output_dir)
		return
	end

	-- 分析指定文件
	read_lua(map)
	read_jass(map)
	read_slk(map, 'abilitybuffdata.slk')
	read_slk(map, 'abilitydata.slk')
	read_slk(map, 'campaignabilityfunc.txt')
	read_slk(map, 'campaignabilitystrings.txt')
	read_slk(map, 'campaignunitfunc.txt')
	read_slk(map, 'campaignunitstrings.txt')
	read_slk(map, 'campaignupgradefunc.txt')
	read_slk(map, 'campaignupgradestrings.txt')
	read_slk(map, 'commandfunc.txt')
	read_slk(map, 'commonabilityfunc.txt')
	read_slk(map, 'commonabilitystrings.txt')
	read_slk(map, 'humanabilityfunc.txt')
	read_slk(map, 'humanabilitystrings.txt')
	read_slk(map, 'humanunitfunc.txt')
	read_slk(map, 'humanunitstrings.txt')
	read_slk(map, 'humanupgradefunc.txt')
	read_slk(map, 'humanupgradestrings.txt')
	read_slk(map, 'itemabilityfunc.txt')
	read_slk(map, 'itemabilitystrings.txt')
	read_slk(map, 'itemdata.slk')
	read_slk(map, 'itemfunc.txt')
	read_slk(map, 'itemstrings.txt')
	read_slk(map, 'neutralabilityfunc.txt')
	read_slk(map, 'neutralabilitystrings.txt')
	read_slk(map, 'neutralunitfunc.txt')
	read_slk(map, 'neutralunitstrings.txt')
	read_slk(map, 'neutralupgradefunc.txt')
	read_slk(map, 'neutralupgradestrings.txt')
	read_slk(map, 'nightelfabilityfunc.txt')
	read_slk(map, 'nightelfabilitystrings.txt')
	read_slk(map, 'nightelfunitfunc.txt')
	read_slk(map, 'nightelfunitstrings.txt')
	read_slk(map, 'nightelfupgradefunc.txt')
	read_slk(map, 'nightelfupgradestrings.txt')
	read_slk(map, 'orcabilityfunc.txt')
	read_slk(map, 'orcabilitystrings.txt')
	read_slk(map, 'orcunitfunc.txt')
	read_slk(map, 'orcunitstrings.txt')
	read_slk(map, 'orcupgradefunc.txt')
	read_slk(map, 'orcupgradestrings.txt')
	read_slk(map, 'undeadabilityfunc.txt')
	read_slk(map, 'undeadabilitystrings.txt')
	read_slk(map, 'undeadunitfunc.txt')
	read_slk(map, 'undeadunitstrings.txt')
	read_slk(map, 'undeadupgradefunc.txt')
	read_slk(map, 'undeadupgradestrings.txt')
	read_slk(map, 'unitabilities.slk')
	read_slk(map, 'unitbalance.slk')
	read_slk(map, 'unitdata.slk')
	read_slk(map, 'unitui.slk')
	read_slk(map, 'unitweapons.slk')
	read_slk(map, 'upgradedata.slk')
	read_w3x(map, 'war3map.w3u')
	read_w3x(map, 'war3map.w3t')
	read_w3x(map, 'war3map.w3b')
	read_w3x(map, 'war3map.w3d')
	read_w3x(map, 'war3map.w3a')
	read_w3x(map, 'war3map.w3h')
	read_w3x(map, 'war3map.w3q')

	map:close()
	fs.remove_all(temp_dir)

	-- 创建报告
	create_log(input_dir:parent_path())
end

main()
