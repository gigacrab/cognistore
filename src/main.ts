const button = document.getElementById("theButton");

// Type assertion is used here to inform TypeScript that the element is an HTMLButtonElement
const theButton = button as HTMLButtonElement;

const handleClick = (event: MouseEvent) => {
    alert("You're sus");
};

theButton.addEventListener('click', handleClick);