ThemeLoader = imports.ThemeLoader;

var name = "Colors";

var colors = [ ThemeLoader.load_svg("colors", "blue.svg"),
               ThemeLoader.load_svg("colors", "green.svg"),
               ThemeLoader.load_svg("colors", "yellow.svg"),
               ThemeLoader.load_svg("colors", "red.svg") ];

var loaded = false;
var textures = [colors[0], colors[1], colors[2], colors[3]];

