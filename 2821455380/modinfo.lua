name = "自动钓鱼"
description = [[
普通淡水鱼竿：自动钓鱼、自动装备鱼竿、自动做鱼竿
玻璃钓竿（能力勋章的内容）：自动钓鱼、自动装备鱼竿（优先）、身上带有蜘蛛丝时自动补充耐久、自动根据当前钓鱼的池塘填充鱼饵
如果鱼塘里面没鱼了，则自动切换附近的鱼塘，如果附近没鱼塘则重新钓鱼，检测时间间隔为游戏内的半天，即半天没上钩则重新钓鱼
]]
author = "DHC"
version = "2.1.3"
forumthread = ""
api_version = 10
icon_atlas = "modicon.xml"
icon = "modicon.tex"
all_clients_require_mod = false
client_only_mod = true
dst_compatible = true
server_filter_tags = {}
priority = -1001

local string = ""

local keys = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12","LAlt","RAlt","LCtrl","RCtrl","LShift","RShift","Tab","Capslock","Space","Minus","Equals","Backspace","Insert","Home","Delete","End","Pageup","Pagedown","Print","Scrollock","Pause","Period","Slash","Semicolon","Leftbracket","Rightbracket","Backslash","Up","Down","Left","Right"}
local keylist = {}
for i = 1, #keys do
    keylist[i] = {description = keys[i], data = "KEY_"..string.upper(keys[i])}
end

configuration_options = {
    {
		name = "KEY",
		label = "快捷键",
		hover = "开启/关闭所使用的快捷键",
		options = keylist,
		default = "KEY_F6"
	},
	{
		name = "highspeed_mode",
		label = "高速模式",
		hover = "低性能电脑请关闭该模式",
		options =
		{
			{description = "开启", data = true},
			{description = "关闭", data = false}
		},
		default = true
	}
}