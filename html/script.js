// Menu state
let isMenuOpen = false;
let questProgress = 0;
const TOTAL_CHECKPOINTS = 150;

// DOM Elements
const menuContainer = document.getElementById('menuContainer');
const progressText = document.getElementById('progressText');
const percentageText = document.getElementById('percentageText');
const progressFill = document.getElementById('progressFill');
const progressGlow = document.getElementById('progressGlow');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    // Card click handlers
    document.querySelectorAll('.menu-card').forEach(card => {
        card.addEventListener('click', () => {
            const action = card.dataset.action;
            handleAction(action);
        });

        // Add hover sound effect (visual feedback)
        card.addEventListener('mouseenter', () => {
            card.style.transition = 'all 0.3s ease';
        });
    });
});

// Handle menu actions
function handleAction(action) {
    switch (action) {
        case 'start':
            sendNUI('startWork');
            closeMenu();
            break;
        case 'end':
            sendNUI('endWork');
            closeMenu();
            break;
    }
}

// Send NUI callback to client
function sendNUI(action, data = {}) {
    fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
}

// Open menu
function openMenu(data) {
    isMenuOpen = true;
    menuContainer.classList.add('active');

    // Update quest progress if provided
    if (data && data.questProgress !== undefined) {
        questProgress = data.questProgress || 0;
        updateProgress();
    }
}

// Close menu
function closeMenu() {
    if (!isMenuOpen) return;

    isMenuOpen = false;
    menuContainer.classList.remove('active');
    sendNUI('closeMenu');
}

// Update progress display with modern calculation
function updateProgress() {
    const percentage = Math.min((questProgress / TOTAL_CHECKPOINTS) * 100, 100);
    const roundedPercentage = Math.round(percentage * 10) / 10;

    // Update text displays
    progressText.textContent = `${questProgress} / ${TOTAL_CHECKPOINTS}`;
    percentageText.textContent = `${roundedPercentage}%`;

    // Update progress bar with smooth animation
    progressFill.style.width = `${percentage}%`;
    progressGlow.style.width = `${percentage}%`;

    // Add completion effect if 100%
    if (percentage >= 100) {
        progressFill.style.background = 'linear-gradient(90deg, #43e97b, #38f9d7, #43e97b)';
    }
}

// Listen for NUI messages from client
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openMenu':
            openMenu(data);
            break;
        case 'closeMenu':
            closeMenu();
            break;
        case 'updateProgress':
            questProgress = data.progress || 0;
            updateProgress();
            break;
    }
});

// ESC key to close
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && isMenuOpen) {
        closeMenu();
    }
});

// Prevent right-click context menu
document.addEventListener('contextmenu', (e) => e.preventDefault());
