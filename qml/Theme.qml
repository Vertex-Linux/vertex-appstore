pragma Singleton
import QtQuick

QtObject {
    id: root

    property string current: "dark"

    // Resolved colors
    property color bg:         themes[current].bg
    property color surface:    themes[current].surface
    property color card:       themes[current].card
    property color accent:     themes[current].accent
    property color accentDim:  themes[current].accentDim
    property color textPri:    themes[current].textPri
    property color textSec:    themes[current].textSec
    property color border:     themes[current].border
    property color sidebar:    themes[current].sidebar
    property color success:    themes[current].success
    property color warning:    themes[current].warning
    property color danger:     themes[current].danger
    property color flatpakClr: themes[current].flatpakClr
    property color pacmanClr:  themes[current].pacmanClr
    property color aurClr:     themes[current].aurClr

    // Font sizes
    property int fontSm:   12
    property int fontMd:   14
    property int fontLg:   16
    property int fontXl:   20
    property int fontXxl:  28

    // Radii
    property int radiusSm: 6
    property int radiusMd: 10
    property int radiusLg: 16

    property var themes: ({
        "dark": {
            bg:         "#0d0f18",
            surface:    "#13162a",
            card:       "#1c1f35",
            accent:     "#7c3aed",
            accentDim:  "#4c1d95",
            textPri:    "#e2e8f0",
            textSec:    "#7c8ba1",
            border:     "#2a2d4a",
            sidebar:    "#10132b",
            success:    "#22c55e",
            warning:    "#f59e0b",
            danger:     "#ef4444",
            flatpakClr: "#3b82f6",
            pacmanClr:  "#22c55e",
            aurClr:     "#f59e0b"
        },
        "light": {
            bg:         "#f1f5f9",
            surface:    "#ffffff",
            card:       "#ffffff",
            accent:     "#7c3aed",
            accentDim:  "#ddd6fe",
            textPri:    "#0f172a",
            textSec:    "#64748b",
            border:     "#e2e8f0",
            sidebar:    "#f8fafc",
            success:    "#16a34a",
            warning:    "#d97706",
            danger:     "#dc2626",
            flatpakClr: "#2563eb",
            pacmanClr:  "#16a34a",
            aurClr:     "#d97706"
        },
        "nord": {
            bg:         "#2e3440",
            surface:    "#3b4252",
            card:       "#434c5e",
            accent:     "#88c0d0",
            accentDim:  "#4c566a",
            textPri:    "#eceff4",
            textSec:    "#d8dee9",
            border:     "#4c566a",
            sidebar:    "#2e3440",
            success:    "#a3be8c",
            warning:    "#ebcb8b",
            danger:     "#bf616a",
            flatpakClr: "#81a1c1",
            pacmanClr:  "#a3be8c",
            aurClr:     "#ebcb8b"
        },
        "catppuccin": {
            bg:         "#1e1e2e",
            surface:    "#181825",
            card:       "#24273a",
            accent:     "#cba6f7",
            accentDim:  "#45475a",
            textPri:    "#cdd6f4",
            textSec:    "#a6adc8",
            border:     "#313244",
            sidebar:    "#181825",
            success:    "#a6e3a1",
            warning:    "#f9e2af",
            danger:     "#f38ba8",
            flatpakClr: "#89dceb",
            pacmanClr:  "#a6e3a1",
            aurClr:     "#f9e2af"
        },
        "gruvbox": {
            bg:         "#282828",
            surface:    "#32302f",
            card:       "#3c3836",
            accent:     "#d79921",
            accentDim:  "#504945",
            textPri:    "#ebdbb2",
            textSec:    "#a89984",
            border:     "#504945",
            sidebar:    "#282828",
            success:    "#98971a",
            warning:    "#d65d0e",
            danger:     "#cc241d",
            flatpakClr: "#458588",
            pacmanClr:  "#98971a",
            aurClr:     "#d79921"
        }
    })

    function apply(name) {
        if (themes[name] !== undefined) {
            current = name
        }
    }
}
