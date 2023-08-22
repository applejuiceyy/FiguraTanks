return {
    withColor = function (text, color)
        printJson('[{"text":"' .. string.gsub(text, "\\", "\\\\"):gsub('"', '\\"') .. '", "color": "#'.. vectors.rgbToHex(color) .. '"}]')
    end
}