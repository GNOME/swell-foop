ThemeLoader = imports.ThemeLoader;

var name = "Shapes and Colors";

var colors = [ ThemeLoader.load_svg("shapesandcolors", "blue.svg"),
               ThemeLoader.load_svg("shapesandcolors", "green.svg"),
	           ThemeLoader.load_svg("shapesandcolors", "yellow.svg"),
               ThemeLoader.load_svg("shapesandcolors", "red.svg")];

var loaded = false;
var textures = [colors[0], colors[1], colors[2], colors[3]];

