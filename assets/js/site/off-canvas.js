/* =====================================================================
   Project override of E25DX's js/site/off-canvas.js.

   Behaviour is unchanged. Three defects are fixed:

   1. `leftSidebarNavActiveItem` is `#left-sidebar > nav > details > ul > li > a.active`,
      which does not exist on a SECTION INDEX page — there the current page
      is the section itself, and its link lives in the <summary>, not in the
      list. The stock script calls .getBoundingClientRect() on that null and
      throws on all seven section index pages, killing the rest of its
      DOMContentLoaded handler (including the sidebar scroll restore).
   2. The resize handler dereferences `rightSidebar` and `leftSidebar`
      unconditionally, so it throws on any page that has only one of them.
   3. Close handlers were registered inside the open handler, so every open
      added another duplicate listener for the life of the page.

   Kept identical: the ids, classes and sessionStorage keys, so
   table-of-contents.js (which reads `body` and `rightSidebarCloseButton`
   from this file's scope through bundle concatenation) still works.
   ===================================================================== */

const body = document.body;
const bodyModelOuter = document.querySelector('#off-canvas-model');

const leftSidebar = document.querySelector('#left-sidebar');
const leftSidebarOpenButton = document.querySelector('#article-nav > button:first-child');
const leftSidebarCloseButton = document.querySelector('#left-sidebar > div .btn');

const rightSidebar = document.querySelector('#right-sidebar');
const rightSidebarOpenButton = document.querySelector('#article-nav > button:last-child');
const rightSidebarCloseButton = document.querySelector('#right-sidebar > div > .btn');

function closePanels() {
    body.classList.remove('model-open');
    if (bodyModelOuter) bodyModelOuter.style.display = 'none';
    if (leftSidebar) leftSidebar.classList.remove('open');
    if (rightSidebar) rightSidebar.classList.remove('open');
}

function wirePanel(panel, openButton, closeButton) {
    if (!panel || !openButton) return;

    openButton.addEventListener('click', function () {
        body.classList.add('model-open');
        if (bodyModelOuter) bodyModelOuter.style.display = 'block';
        panel.classList.add('open');
        const first = panel.querySelector('a, button');
        if (first) first.focus({ preventScroll: true });
    });

    if (closeButton) closeButton.addEventListener('click', closePanels);
}

wirePanel(leftSidebar, leftSidebarOpenButton, leftSidebarCloseButton);
wirePanel(rightSidebar, rightSidebarOpenButton, rightSidebarCloseButton);

if (bodyModelOuter) bodyModelOuter.addEventListener('click', closePanels);

document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && body.classList.contains('model-open')) {
        closePanels();
    }
});

window.addEventListener('resize', function () {
    if (body.classList.contains('model-open')) closePanels();
});

/* ---- sidebar height + scroll position ------------------------------- */

const leftSidebarSiteLogo = document.querySelector('#left-sidebar .site-logo');
const leftSidebarNav = document.querySelector('#left-sidebar > nav');

if (leftSidebarNav) {
    const logoHeight = () =>
        leftSidebarSiteLogo ? leftSidebarSiteLogo.getBoundingClientRect().height : 0;

    // The stock script sized the nav in JS as `innerHeight - logo height`,
    // because the theme's sidebar is not a flex column. This project's is
    // (see vol/chrome.css), so `flex: 1` + `overflow-y: auto` already gives
    // the nav exactly the leftover height. Keeping the JS sizing on top of
    // that overflowed the sidebar as soon as anything else was added to the
    // column — the header band that continues the header's rule across the
    // sidebar at >=1280 did precisely that. Layout is left to CSS.

    const section = window.location.pathname.split('/').filter(Boolean)[0] || 'default';
    const sectionSidebarPositionKey = `${section}-sidebar-position`;

    const restoreScroll = function () {
        const savedScroll = sessionStorage.getItem(sectionSidebarPositionKey);

        if (savedScroll !== null) {
            leftSidebarNav.scrollTop = parseInt(savedScroll, 10);
            return;
        }

        // Absent on section index pages, where the current page's link is the
        // <summary> rather than a list item. Nothing to scroll to; not an error.
        const activeItem = leftSidebarNav.querySelector('details > ul > li > a.active');
        if (!activeItem) return;

        const navRect = leftSidebarNav.getBoundingClientRect();
        const itemRect = activeItem.getBoundingClientRect();
        const isVisible = itemRect.top >= navRect.top && itemRect.bottom <= navRect.bottom;

        if (!isVisible) {
            leftSidebarNav.scrollTo({
                top: activeItem.offsetTop - leftSidebarNav.offsetTop - logoHeight(),
                behavior: 'auto',
            });
        }
    };

    if (document.readyState === 'loading') {
        window.addEventListener('DOMContentLoaded', restoreScroll);
    } else {
        restoreScroll();
    }

    window.addEventListener('beforeunload', () => {
        sessionStorage.setItem(sectionSidebarPositionKey, leftSidebarNav.scrollTop);
    });
}
