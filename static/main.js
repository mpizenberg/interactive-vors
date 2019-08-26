import { activatePorts } from "./ports.js"

console.log("body script");
// Function returning the size of the container element for the app.
// In our case, the full layout viewport.
const layoutViewportSize = () => ({
	width: document.documentElement.clientWidth,
	height: document.documentElement.clientHeight
});
var app = Elm.Main.init({
	node: document.getElementById('elm')
});
activatePorts(app, layoutViewportSize);
