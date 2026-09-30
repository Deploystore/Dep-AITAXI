/* =========================================================
   STANDALONE RIGHT-SIDE AI CONTROL PANEL VANILLA JS
   ========================================================= */
(function() {
    let currentLocales = null;

    function applyLocalesToUI(locales) {
        if (!locales) return;
        currentLocales = locales;

        const roleSub = document.querySelector('.rsd-header-info .role-subtitle');
        if (roleSub && locales.role_sub) roleSub.innerText = locales.role_sub;

        const controlHeader = document.querySelector('.panel-section-title span');
        if (controlHeader && locales.ai_control_header) controlHeader.innerText = locales.ai_control_header;

        const actionMap = {
            'sport': { title: locales.sport_title, desc: locales.sport_desc },
            'hazard': { title: locales.hazard_title, desc: locales.hazard_desc },
            'lock': { title: locales.lock_title, desc: locales.lock_desc },
            'ac': { title: locales.ac_title, desc: locales.ac_desc },
            'wait': { title: locales.wait_title, desc: locales.wait_desc },
            'stop': { title: locales.stop_title, desc: locales.stop_desc },
            'fast': { title: locales.boost_title, desc: locales.boost_desc },
            'horn': { title: locales.horn_title, desc: locales.horn_desc },
            'windows': { title: locales.windows_title, desc: locales.windows_desc },
            'light': { title: locales.light_title, desc: locales.light_desc },
            'cautious': { title: locales.cautious_title, desc: locales.cautious_desc },
            'music': { title: locales.music_title, desc: locales.music_desc }
        };

        for (const action in actionMap) {
            const card = document.querySelector(`.action-white-card[data-action="${action}"]`);
            if (card) {
                const titleElem = card.querySelector('.card-title');
                const descElem = card.querySelector('.card-desc');
                if (titleElem && actionMap[action].title) titleElem.innerText = actionMap[action].title;
                if (descElem && actionMap[action].desc) descElem.innerText = actionMap[action].desc;
            }
        }
    }

    window.addEventListener('message', function(event) {
        const item = event.data;
        if (!item) return;

        const root = document.getElementById('ai-boarding-dialog-root');
        if (!root) return;

        if (item.action === 'OPEN_TAXI_UI' || item.action === 'OPEN_UI') {
            if (item.data && item.data.config && item.data.config.locales) {
                applyLocalesToUI(item.data.config.locales);
            }
        } else if (item.action === 'SHOW_BOARDING_QUESTION') {
            const driverElem = document.getElementById('rsd-driver-name');
            if (driverElem && item.data && item.data.driverName) {
                driverElem.innerText = item.data.driverName;
            }

            if (item.data && item.data.locales) {
                applyLocalesToUI(item.data.locales);
            }

            root.classList.remove('hidden');
            root.classList.add('visible');
            setTimeout(updateCardsArcCurve, 80);
        } else if (item.action === 'HIDE_BOARDING_QUESTION') {
            root.classList.remove('visible');
            root.classList.add('hidden');
        } else if (item.action === 'SHOW_AI_HANDLE') {
            const handle = document.getElementById('ai-panel-toggle-handle');
            if (handle) handle.classList.remove('hidden');
        } else if (item.action === 'HIDE_AI_HANDLE') {
            const handle = document.getElementById('ai-panel-toggle-handle');
            if (handle) handle.classList.add('hidden');
            root.classList.remove('visible');
            root.classList.add('hidden');
        }
    });

    document.addEventListener('click', function(e) {
        const handleBtn = e.target.closest('#ai-panel-toggle-handle');
        if (handleBtn) {
            const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'DepAITaxi';
            fetch(`https://${resourceName}/openBoardingPanel`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            }).catch(function(err) {});
            return;
        }
    });

    document.addEventListener('DOMContentLoaded', function() {

        const cardsList = document.querySelector('.panel-cards-list');
        const scrollDot = document.querySelector('.scroll-cyan-dot');
        if (cardsList) {
            cardsList.addEventListener('scroll', function() {
                if (scrollDot) {
                    const maxScroll = cardsList.scrollHeight - cardsList.clientHeight;
                    if (maxScroll > 0) {
                        const scrollPercent = cardsList.scrollTop / maxScroll;
                        scrollDot.style.transform = `translateY(${scrollPercent * 135}px)`;
                    }
                }
                updateCardsArcCurve();
            });
            setTimeout(updateCardsArcCurve, 60);
        }
    });

    function updateCardsArcCurve() {
        const cardsContainer = document.querySelector('.panel-cards-list');
        if (!cardsContainer) return;

        const cards = cardsContainer.querySelectorAll('.action-white-card');
        const containerHeight = cardsContainer.clientHeight;
        if (containerHeight <= 0) return;
        const containerCenterY = containerHeight / 2;

        cards.forEach(card => {
            const cardCenterY = (card.offsetTop - cardsContainer.scrollTop) + (card.offsetHeight / 2);
            let normalizedDist = (cardCenterY - containerCenterY) / containerCenterY;
            normalizedDist = Math.max(-1.15, Math.min(1.15, normalizedDist));

            const arcOffset = Math.pow(normalizedDist, 2) * 44;
            card.style.marginLeft = `${Math.round(arcOffset)}px`;
        });
    }

    window.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' || e.keyCode === 27) {
            const root = document.getElementById('ai-boarding-dialog-root');
            if (root && root.classList.contains('visible')) {
                answerBoardingPrompt('close');
            }
        }
    });

    function answerBoardingPrompt(answer) {
        if (answer === 'close') {
            const root = document.getElementById('ai-boarding-dialog-root');
            if (root) {
                root.classList.remove('visible');
                root.classList.add('hidden');
            }
        }

        const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'DepAITaxi';
        fetch(`https://${resourceName}/boardingQuestionAnswer`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ answer: answer })
        }).catch(function(e) {});
    }
})();
