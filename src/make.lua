--添加require搜寻路径
package.path = package.path .. ';src\\?.lua'
package.cpath = package.cpath .. ';build\\?.dll'

require 'luabind'
require 'filesystem'
require 'utility'
require 'localization'

for name in pairs(fs) do
	--print(name)
end

local temp_dir    = fs.path('temp')
local encrypt_name = '%s体.mdl'

local function extract(map, filename, dir)
	-- 尝试导出文件
	if not map:extract(filename, dir) then
		return nil
	end
	local file = io.open(dir, 'rb')
	if not file then
		return nil
	end
	local content = file:read 'a'
	file:close()
	return content
end

local encrypt_list = {}
local function encrypt_model(map, name, reason)
	if encrypt_list[name] then
		encrypt_list[name] = reason
		return true
	end
	local new_name = encrypt_name:format(name)
	if map:rename(name .. '.mdl', new_name) or map:rename(name .. '.mdx', new_name) then
		encrypt_list[name] = reason
		print('rename', name, new_name, reason)
		return true
	end
	return false
end

local function read_jass(map)
	local jass = extract(map, 'script\\war3map.j', temp_dir / 'war3map.j') or extract(map, 'war3map.j', temp_dir / 'war3map.j')
	if not jass then
		print '[错误]	没有找到脚本'
		return
	end
	
	local new_jass = jass:gsub('[^\\]"(%C*).md[lx]"', function(name)
		if encrypt_model(map, name:gsub([[\\]], [[\]]), '脚本') then
			return '"' .. encrypt_name:format(name) .. '"'
		end
	end)
	
	local file = io.open(temp_dir / 'war3map.j', 'wb')
	file:write(new_jass)
	file:close()

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

	local new_slk = slk:gsub('"(%C*).md[lx]"', function(name)
		if encrypt_model(map, name, '单位表(slk)') then
			return '"' .. encrypt_name:format(name) .. '"'
		end
	end)
	
	local file = io.open(temp_dir / 'unitui.slk', 'wb')
	file:write(new_slk)
	file:close()
	
	map:import('units\\unitui.slk', temp_dir / 'unitui.slk')
end

--local function read_w3u(map)
--	local w3u = extract(map, 'war3map.w3u', temp_dir / 'war3map.w3u')
--	if not w3u then
--		return
--	end
--
--	local new_w3u = w3u:gsub('"(%C*).md[lx]"', function(name)
--		if encrypt_model(map, name, '单位表(w3u)') then
--			return '"' .. encrypt_name:format(name) .. '"'
--		end
--	end)
--
--	local file = io.open(temp_dir / 'war3map.w3u', 'wb')
--	file:write(new_w3u)
--	file:close()
--
--	map:import('war3map.w3u', temp_dir / 'war3map.w3u')
--end

local function main()
	-- 检查参数 arg[1]为地图, arg[2]为本地路径
	if not arg or #arg < 2 then
		print '[错误]	请将要加密的地图拖动到bat中'
		return
	end

	-- 保存路径
	local input_dir  = fs.path(arg[1])
	local root_dir   = fs.path(arg[2])
	local output_dir = fs.path('模型加密过的' .. input_dir:filename():string())

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
	--read_w3u(map)	

	map:close()
end

main()
