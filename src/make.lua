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

local function create_log()
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
	io.save(fs.path '模型加密报告.txt', table.concat(list, '\n'))
	print('[成功]	' .. success)
	print('[成功]	查看 "模型加密报告.txt" 了解更多信息')
end

local function read_jass(map)
	local jass = extract(map, 'script\\war3map.j', temp_dir / 'war3map.j') or extract(map, 'war3map.j', temp_dir / 'war3map.j')
	if not jass then
		print '[错误]	没有找到脚本'
		return
	end
	
	local new_jass = jass:gsub('([^\\]")(%C*)(.md[lx]")', function(str1, name, str2)
		if encrypt_model(map, name:gsub([[\\]], [[\]]), '脚本(jass)') then
			return str1 .. encrypt_name:format(name) .. str2
		end
	end)
	
	io.save(temp_dir / 'war3map.j', new_jass)

	if map:remove 'script\\war3map.j' then
		map:import('script\\war3map.j', temp_dir / 'war3map.j')
	end
	if map:remove 'war3map.j' then
		map:import('war3map.j', temp_dir / 'war3map.j')
	end
end

local function read_slk(map)
	local slk = extract(map, 'units\\unitui.slk', temp_dir / 'unitui.slk')
	if not slk then
		return
	end

	local new_slk = slk:gsub('(")(%C*)(.md[lx]")', function(str1, name, str2)
		if encrypt_model(map, name, '单位表(slk)') then
			return str1 .. encrypt_name:format(name) .. str2
		end
	end)
	
	io.save(temp_dir / 'unitui.slk', new_slk)
	
	map:import('units\\unitui.slk', temp_dir / 'unitui.slk')
end

local function read_w3u(map)
	local w3u = extract(map, 'war3map.w3u', temp_dir / 'war3map.w3u')
	if not w3u then
		return
	end

	local new_w3u = w3u:gsub('(\0)(%C*)(%.md[lx]\0)', function(str1, name, str2)
		if encrypt_model(map, name, '单位表(w3u)') then
			return str1 .. encrypt_name:format(name) .. str2
		end
	end)

	io.save(temp_dir / 'war3map.w3u', new_w3u)

	map:import('war3map.w3u', temp_dir / 'war3map.w3u')
end

local function main()
	-- 检查参数 arg[1]为地图, arg[2]为本地路径
	if not arg or #arg < 2 then
		print '[错误]	请将要加密的地图拖动到bat中'
		return
	end
	
	--添加require搜寻路径
	package.path = package.path .. ';' .. arg[2] .. 'src\\?.lua'
	package.cpath = package.cpath .. ';' .. arg[2] .. 'build\\?.dll'
	require 'utility'
	require 'localization'

	-- 保存路径
	local input_dir  = fs.path(ansi_to_utf8(arg[1]))
	local root_dir   = fs.path(ansi_to_utf8(arg[2]))

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

	-- 用storm打开复制出来的地图
	local map = mpq_open(output_dir)
	if not map then
		print '[错误]	地图打开失败,可能是使用了特殊的加密手段,或者根本不是地图'
		fs.remove(output_dir)
		return
	end

	-- 导出指定文件
	read_jass(map)
	read_slk(map)
	read_w3u(map)

	map:close()
	fs.remove_all(temp_dir)

	-- 创建报告
	create_log()
end

main()
