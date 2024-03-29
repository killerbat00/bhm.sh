'use strict';

var navLinks = {
    home: document.getElementById("homeNavLink"),
    now: document.getElementById("nowNavLink"),
    about: document.getElementById("aboutNavLink"),
    resume: document.getElementById("resumeNavLink"),
    extras: document.getElementById("extrasNavLink"),
    darkModeBtn: document.getElementById("darkMode"),
    lightModeBtn: document.getElementById("lightMode"),
    einsteinDark: document.getElementById("einsteinDark"),
    einsteinLight: document.getElementById("einsteinLight"),
};

var root = document.body;
var setTheme = function (newTheme) {
    if (newTheme === "dark" || newTheme === "light") {
        root.setAttribute("data-theme", newTheme);
        localStorage.setItem("theme", newTheme);
    }

    if (newTheme === "dark") {
        navLinks.darkModeBtn.style.display = "none";
        navLinks.lightModeBtn.style.display = "initial";
        navLinks.einsteinLight.style.display = "none";
        navLinks.einsteinDark.style.display = "initial";
    } else if (newTheme === "light") {
        navLinks.lightModeBtn.style.display = "none";
        navLinks.darkModeBtn.style.display = "initial";
        navLinks.einsteinDark.style.display = "none";
        navLinks.einsteinLight.style.display = "initial";
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

var colorLink = function (linkEl) {
    linkEl.classList.add("activeLink");
}

var currentPage = window.location.pathname.split("/");
switch (currentPage[1]) {
    case "":
        colorLink(navLinks.home);
        break;
    case "now":
        colorLink(navLinks.now);
        break;
    case "about":
        colorLink(navLinks.about);
        break;
    case "resume":
        colorLink(navLinks.resume);
        break;
    case "vault":
        colorLink(navLinks.extras);
        break;
}