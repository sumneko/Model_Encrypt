--添加require搜寻路径
package.path = package.path .. ';src\\?.lua'
package.cpath = package.cpath .. ';build\\?.dll'

require 'luabind'
require 'filesystem'
require 'utility'
require 'localization'
require 'stormlib'

local function main()
	--检查参数 arg[1]为地图, arg[2]为本地路径
	if not arg or #arg < 2 then
		print '请将要加密的地图拖动到bat中'
		return
	end

	--保存路径
	input_map	= fs.path(arg[1])
	root_dir	= fs.path(arg[2])
end

main()
