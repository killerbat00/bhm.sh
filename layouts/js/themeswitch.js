'use strict';

var navLinks = {
    home: document.getElementById("homeNavLink"),
    now: document.getElementById("nowNavLink"),
    about: document.getElementById("aboutNavLink"),
    resume: document.getElementById("resumeNavLink"),
    darkModeBtn: document.getElementById("darkMode"),
    lightModeBtn: document.getElementById("lightMode"),
};

var root = document.body;
var setTheme = function (newTheme) {
    if (newTheme === "dark" || newTheme === "light") {
        root.setAttribute("data-theme", newTheme);
        localStorage.setItem("theme", newTheme);
    }

    if (newTheme === "dark") {
        navLinks.darkModeBtn.style.display = "none";
        navLinks.lightModeBtn.style.display = "block";
        navLinks.lightModeBtn.style.margin = "0 auto";
    } else if (newTheme === "light") {
        navLinks.lightModeBtn.style.display = "none";
        navLinks.darkModeBtn.style.display = "block";
        navLinks.darkModeBtn.style.margin = "0 auto";
    }
}

navLinks.darkModeBtn.addEventListener("click", function () {
    setTheme("dark");
});

navLinks.lightModeBtn.addEventListener("click", function () {
    setTheme("light");
})

var prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
var storedTheme = localStorage.getItem("theme");
setTheme(storedTheme === null ? prefersDark ? "dark" : "light" : storedTheme);

window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function (event) {
    var newTheme = event.matches ? "dark" : "light";
    setTheme(newTheme);
});

var colorLink = (linkEl) => {
    linkEl.classList.add("activeLink");
}

var currentPage = window.location.pathname;
switch (currentPage) {
    case "/":
    case "/index":
    case "/index.html":
        colorLink(navLinks.home);
        break;
    case "/now":
    case "/now.html":
        colorLink(navLinks.now);
        break;
    case "/about":
    case "/about.html":
        colorLink(navLinks.about);
        break;
    case "/resume":
    case "/resume.html":
        colorLink(navLinks.resume);
        break;
}