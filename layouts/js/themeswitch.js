'use strict';

var colors = {
    dark: {
        bgcolor: "rgb(40, 40, 40)",
        textcolor: "rgb(230, 230, 230)",
        bqcolor: "rgb(100, 100, 100)",
        aside: "rgb(120, 120, 120)"
    },
    light: {
        bgcolor: "rgb(255, 255, 255)",
        textcolor: "rgb(0, 0, 0)",
        bqcolor: "rgb(238, 238, 238)",
        aside: "rgb(150, 150, 150)"
    }
};

var navLinks = {
    home: document.getElementById("homeNavLink"),
    now: document.getElementById("nowNavLink"),
    about: document.getElementById("aboutNavLink"),
    resume: document.getElementById("resumeNavLink"),
};

var root = document.documentElement;
var darkModeBtn = document.getElementById("darkMode");
var lightModeBtn = document.getElementById("lightMode");

function setDarkMode() {
    root.style.setProperty("--bg-color", colors.dark.bgcolor);
    root.style.setProperty("--text-color", colors.dark.textcolor);
    root.style.setProperty("--blockquote-color", colors.dark.bqcolor);
    root.style.setProperty("--text-color-aside", colors.dark.aside);
    darkModeBtn.style.display = "none";
    lightModeBtn.style.display = "block";
    lightModeBtn.style.margin = "0 auto";
    localStorage.removeItem("lightMode");
    localStorage.setItem("darkMode", "enabled");
}

function setLightMode() {
    root.style.setProperty("--bg-color", colors.light.bgcolor);
    root.style.setProperty("--text-color", colors.light.textcolor);
    root.style.setProperty("--blockquote-color", colors.light.bqcolor);
    root.style.setProperty("--text-color-aside", colors.light.aside);
    lightModeBtn.style.display = "none";
    darkModeBtn.style.display = "block";
    darkModeBtn.style.margin = "0 auto";
    localStorage.removeItem("darkMode");
    localStorage.setItem("lightMode", "enabled");
}

var isDarkMode = localStorage.getItem("darkMode") === "enabled";
var isLightMode = localStorage.getItem("lightMode") === "enabled";

if (isDarkMode) {
    setDarkMode();
}

if (isLightMode) {
    setLightMode();
}

if (darkModeBtn) {
    darkModeBtn.addEventListener("click", setDarkMode);
}

if (lightModeBtn) {
    lightModeBtn.addEventListener("click", setLightMode);
}

if (window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener("change", function (event) {
        var newColorScheme = event.matches ? "dark" : "light";
        if (newColorScheme === "dark") {
            setDarkMode();
        } else {
            setLightMode();
        }
    });
}

function colorActiveLink(linkEl) {
    linkEl.classList.add("activeLink");
}

var currentPage = window.location.pathname;
switch (currentPage) {
    case "/":
    case "/index":
    case "/index.html":
        colorActiveLink(navLinks.home);
        break;
    case "/now":
    case "/now.html":
        colorActiveLink(navLinks.now);
        break;
    case "/about":
    case "/about.html":
        colorActiveLink(navLinks.about);
        break;
    case "/resume":
    case "/resume.html":
        colorActiveLink(navLinks.resume);
        break;
}