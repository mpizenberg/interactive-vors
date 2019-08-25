const template = document.createElement('template');
template.innerHTML = "<span id=content><span>";

class Renderer extends HTMLElement {
	constructor() {
		super();
		this.max = 0;
		this.value = 0;
		this.attachShadow({ mode: 'open' });
		this.shadowRoot.appendChild(template.content.cloneNode(true));
		this.content = this.shadowRoot.getElementById("content");
	}

	static get observedAttributes() {
		return ['value', 'trigger-compute'];
	}

	attributeChangedCallback(name, oldValue, newValue) {
		switch (name) {
			case 'value':
				console.log(`Value changed from ${oldValue} to ${newValue}`);
				this.value = +newValue;
				this.updateContent();
				break;
			case 'trigger-compute':
				console.log(`Asking for computation!`);
				this.max += 1;
				this.updateContent();
				break;
		}
	}

	updateContent() {
		this.content.innerHTML = `value: ${this.value}, max: ${this.max}`
	}

	connectedCallback() {
		console.log("connected");
	}

	disconnectedCallback() {
		console.log("disconnected");
	}
}

window.customElements.define("custom-renderer", Renderer);
