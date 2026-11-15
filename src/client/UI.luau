-- UI.luau (client) — one tiny constructor helper so HUD and Screens build
-- their instances the same way instead of repeating property blocks.

local UI = {}

-- UI.Create("TextLabel", { Size = ..., Text = ..., Parent = ... })
function UI.Create(className: string, props: { [string]: any }): Instance
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

function UI.Corner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

-- A standard menu button: bold text on a solid colour, rounded.
function UI.Button(parent: Instance, text: string, color: Color3, size: UDim2): TextButton
	local button = UI.Create("TextButton", {
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 18,
		AutoButtonColor = true,
		Parent = parent,
	}) :: TextButton
	UI.Corner(button, 10)
	return button
end

return UI
