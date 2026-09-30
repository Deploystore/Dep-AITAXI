const { createApp, ref, computed, onMounted, onUnmounted } = Vue;

createApp({
    setup() {
        const visible = ref(false);
        const currentScreen = ref('welcome'); // 'welcome' | 'console'

        // Config defaults
        const config = ref({
            baseFare: 20,
            pricePerKM: 10,
            currency: '$',
            driverName: 'Niko Bellic',
            driverRating: 4.9,
            vehicleModel: 'vivanite2',
            destinations: [],
            drivingStyles: {
                'cautious': { label: 'Sakin ve Güvenli' },
                'normal':   { label: 'Normal Sürüş' },
                'fast':     { label: 'Acele ve Hızlı' }
            },
            defaultStyle: 'normal'
        });

        const selectedVehicle = ref('vivanite2');
        const vehicles = ref([
            { 
                id: 'vivanite2', 
                brand: 'DepTAXI', 
                model: 'DriveAI', 
                fullName: 'DepTAXI DriveAI',
                tagline: 'Real-time obstacle', 
                theme: 'theme-neuro',
                accentColor: '#f59e0b',
                glowColor: 'radial-gradient(circle at 75% 70%, rgba(245, 158, 11, 0.45) 0%, rgba(245, 158, 11, 0.12) 45%, transparent 75%)',
                image: 'img/car.png',
                isFavorite: true
            },
            { 
                id: 'lumo', 
                brand: 'LUMO', 
                model: 'NMK23', 
                fullName: 'LUMO NMK23',
                tagline: 'Adaptive lighting system', 
                theme: 'theme-lumo',
                accentColor: '#10b981',
                glowColor: 'radial-gradient(circle at 75% 70%, rgba(16, 185, 129, 0.45) 0%, rgba(16, 185, 129, 0.12) 45%, transparent 75%)',
                image: 'img/car.png',
                isFavorite: false
            },
            { 
                id: 'cyber', 
                brand: 'CYBER', 
                model: 'CAB', 
                fullName: 'CYBER CAB',
                tagline: 'Autonomous hyperdrive', 
                theme: 'theme-cyber',
                accentColor: '#06b6d4',
                glowColor: 'radial-gradient(circle at 75% 70%, rgba(6, 182, 212, 0.45) 0%, rgba(6, 182, 212, 0.12) 45%, transparent 75%)',
                image: 'img/car.png',
                isFavorite: false
            }
        ]);

        const selectedVehicleData = computed(() => {
            return vehicles.value.find(v => v.id === selectedVehicle.value) || vehicles.value[0];
        });

        const toggleFavorite = (veh) => {
            veh.isFavorite = !veh.isFavorite;
        };

        const activeTrip = ref(false);
        const inCarHUD = ref(false);
        const meterStatus = ref('Hazır');
        const liveDistance = ref('0.00');
        const liveFare = ref('20.00');

        const selectedStyle = ref('normal');

        // Infinite Horizon Bezier Curve Paths (Extending y = -350 all the way to top horizon edge!)
        const straightRoad = {
            roadD: 'M 160 700 L 160 -350',
            roadEdgeLeftD: 'M 22 700 L 22 -350',
            roadEdgeRightD: 'M 298 700 L 298 -350',
            laserD: 'M 215 700 L 215 -350',
            sceneTransform: 'rotateX(52deg) rotateY(0deg) rotateZ(0deg)',
            carTransform: 'translateX(55px) rotate(0deg)'
        };

        const leftTurnRoad = {
            roadD: 'M 160 700 C 160 360, 90 200, -180 -350',
            roadEdgeLeftD: 'M 22 700 C 22 360, -48 200, -318 -350',
            roadEdgeRightD: 'M 298 700 C 298 360, 228 200, -42 -350',
            laserD: 'M 215 700 C 215 360, 135 190, -130 -350',
            sceneTransform: 'rotateX(52deg) rotateY(-10deg) rotateZ(15deg)',
            carTransform: 'translateX(5px) rotate(-22deg)'
        };

        const rightTurnRoad = {
            roadD: 'M 160 700 C 160 360, 230 200, 500 -350',
            roadEdgeLeftD: 'M 22 700 C 22 360, 92 200, 362 -350',
            roadEdgeRightD: 'M 298 700 C 298 360, 368 200, 638 -350',
            laserD: 'M 215 700 C 215 360, 285 190, 560 -350',
            sceneTransform: 'rotateX(52deg) rotateY(10deg) rotateZ(-15deg)',
            carTransform: 'translateX(110px) rotate(22deg)'
        };

        // Dynamic Waymo / Tesla FSD Simulation State
        const fsdSim = ref({
            trafficLight: 'green',
            showTrafficLight: false, // Only visible at intersections!
            roadCurve: 'none', // 'none' | 'left' | 'right'
            isDriving: true,
            speedKMH: 52,
            actionNotice: 'AUTONOMOUS CRUISE • 52 KM/H',
            isLiveFiveM: false,
            ...straightRoad
        });

        let simTimer = null;
        let lastTelemetryTime = 0;

        const startFSDSimulation = () => {
            let step = 0;
            if (simTimer) clearInterval(simTimer);

            simTimer = setInterval(() => {
                // If live FiveM telemetry was received in the last 1.8 seconds, skip demo loop
                if (Date.now() - lastTelemetryTime < 1800) {
                    return;
                }

                step = (step + 1) % 6;

                if (step === 0) {
                    // Straight Cruise (No Traffic Light!)
                    fsdSim.value = {
                        trafficLight: 'green',
                        showTrafficLight: false,
                        roadCurve: 'none',
                        isDriving: true,
                        speedKMH: 52,
                        actionNotice: 'AUTONOMOUS CRUISE • 52 KM/H',
                        isLiveFiveM: false,
                        ...straightRoad
                    };
                } else if (step === 1) {
                    // Smooth 90° Left Curve Turn (No Traffic Light!)
                    fsdSim.value = {
                        trafficLight: 'green',
                        showTrafficLight: false,
                        roadCurve: 'left',
                        isDriving: true,
                        speedKMH: 34,
                        actionNotice: 'LEFT TURN • 90° ROUTE CURVE',
                        isLiveFiveM: false,
                        ...leftTurnRoad
                    };
                } else if (step === 2) {
                    // Approaching Intersection Yellow Light (Traffic Light Appears at Sidewalk Curb!)
                    fsdSim.value = {
                        trafficLight: 'yellow',
                        showTrafficLight: true,
                        roadCurve: 'none',
                        isDriving: true,
                        speedKMH: 18,
                        actionNotice: 'YELLOW LIGHT • SLOWING DOWN',
                        isLiveFiveM: false,
                        ...straightRoad,
                        carTransform: 'translateX(45px) rotate(-2deg)'
                    };
                } else if (step === 3) {
                    // Stopped at Intersection Red Light (Traffic Light Visible at Sidewalk Curb!)
                    fsdSim.value = {
                        trafficLight: 'red',
                        showTrafficLight: true,
                        roadCurve: 'none',
                        isDriving: false,
                        speedKMH: 0,
                        actionNotice: '🔴 STOPPED AT RED LIGHT',
                        isLiveFiveM: false,
                        ...straightRoad,
                        carTransform: 'translateX(55px) rotate(0deg)'
                    };
                } else if (step === 4) {
                    // Smooth 90° Right Curve Turn (No Traffic Light!)
                    fsdSim.value = {
                        trafficLight: 'green',
                        showTrafficLight: false,
                        roadCurve: 'right',
                        isDriving: true,
                        speedKMH: 32,
                        actionNotice: 'RIGHT TURN • INTERSECTION BEND',
                        isLiveFiveM: false,
                        ...rightTurnRoad
                    };
                } else if (step === 5) {
                    // Re-entering Center Driving Lane (No Traffic Light!)
                    fsdSim.value = {
                        trafficLight: 'green',
                        showTrafficLight: false,
                        roadCurve: 'none',
                        isDriving: true,
                        speedKMH: 50,
                        actionNotice: 'LANE RE-CENTERED • OPTIMAL ROUTE',
                        isLiveFiveM: false,
                        ...straightRoad
                    };
                }
            }, 3600);
        };

        // Preferences State
        const preferences = ref({
            music: true,
            ac: true,
            quiet: false,
            highway: true,
            vip: true
        });

        const subPreferences = ref({
            musicGenre: 'Lo-Fi Beats',
            quietType: 'Sohbet Edebilir',
            routeType: 'En Hızlı Otoban',
            vipColor: 'Neon Mor'
        });

        const L = (key, fallback = '') => {
            const locs = (config.value && config.value.locales) || {};
            return locs[key] || fallback;
        };

        const musicGenres = ref(['Lo-Fi Beats', '80s Synthwave', 'Pop Hits', 'Radio Off']);

        const quietTypes = computed(() => [
            L('quiet_type_silent', 'Tam Sessiz'),
            L('quiet_type_greetings', 'Sadece Selamlaşma'),
            L('quiet_type_conversational', 'Sohbet Edebilir')
        ]);

        const routeTypes = computed(() => [
            L('route_type_fastest', 'En Hızlı Otoban'),
            L('route_type_scenic', 'Manzaralı Sahil Yolu'),
            L('route_type_city', 'Şehir İçi Rota')
        ]);

        const vipColors = computed(() => [
            { key: 'purple', name: 'Neon Mor',     label: L('neon_purple', 'Neon Purple'), color: '#a855f7', glow: 'rgba(168, 85, 247, 0.65)' },
            { key: 'pink',   name: 'Pembe Glow',   label: L('neon_pink', 'Pink Glow'),     color: '#ec4899', glow: 'rgba(236, 72, 153, 0.65)' },
            { key: 'blue',   name: 'Okyanus Mavi', label: L('neon_blue', 'Ocean Blue'),   color: '#00f2ff', glow: 'rgba(0, 242, 255, 0.65)' },
            { key: 'green',  name: 'Siber Yeşil',  label: L('neon_green', 'Cyber Green'),  color: '#10b981', glow: 'rgba(16, 185, 129, 0.65)' },
            { key: 'yellow', name: 'Altın Sarı',   label: L('neon_yellow', 'Gold Yellow'), color: '#f59e0b', glow: 'rgba(245, 158, 11, 0.65)' },
            { key: 'red',    name: 'Alev Kırmızı', label: L('neon_red', 'Flame Red'),     color: '#ef4444', glow: 'rgba(239, 68, 68, 0.65)' },
            { key: 'white',  name: 'Saf Beyaz',    label: L('neon_white', 'Pure White'),   color: '#ffffff', glow: 'rgba(255, 255, 255, 0.65)' }
        ]);

        const selectedVipColorObj = computed(() => {
            return vipColors.value.find(c => c.name === subPreferences.value.vipColor || c.key === subPreferences.value.vipColor || c.label === subPreferences.value.vipColor) || vipColors.value[0];
        });

        const youtubeUrl = ref('');

        const playCustomYouTube = () => {
            if (!youtubeUrl.value) return;
            subPreferences.value.musicGenre = 'YouTube: ' + youtubeUrl.value;
        };

        const togglePreference = (key) => {
            preferences.value[key] = !preferences.value[key];
        };

        // =========================================================
        // 3D SPATIAL AUDIO & DISTANCE ATTENUATION ENGINE
        // =========================================================
        let spatialAudioCtx = null;
        let spatialGainNode = null;
        let spatialPannerNode = null;
        let currentDistVolume = 1.0;
        let currentPan = 0.0;
        let baseTtsVolume = 1.0;
        let baseMediaVolume = 0.45;

        const initSpatialAudio = () => {
            if (!spatialAudioCtx) {
                try {
                    const AudioCtxClass = window.AudioContext || window.webkitAudioContext;
                    if (AudioCtxClass) {
                        spatialAudioCtx = new AudioCtxClass();
                        spatialGainNode = spatialAudioCtx.createGain();
                        if (spatialAudioCtx.createStereoPanner) {
                            spatialPannerNode = spatialAudioCtx.createStereoPanner();
                            spatialGainNode.connect(spatialPannerNode);
                            spatialPannerNode.connect(spatialAudioCtx.destination);
                        } else {
                            spatialGainNode.connect(spatialAudioCtx.destination);
                        }
                    }
                } catch (e) {
                    console.log('Spatial Audio initialization:', e);
                }
            }
            if (spatialAudioCtx && spatialAudioCtx.state === 'suspended') {
                spatialAudioCtx.resume().catch(e => {});
            }
        };

        const update3DSpatialAudio = (data) => {
            if (!data) return;
            currentDistVolume = typeof data.distVolume === 'number' ? data.distVolume : 1.0;
            currentPan = typeof data.pan === 'number' ? data.pan : 0.0;

            if (spatialAudioCtx && spatialGainNode) {
                try {
                    spatialGainNode.gain.setValueAtTime(currentDistVolume, spatialAudioCtx.currentTime);
                    if (spatialPannerNode) {
                        spatialPannerNode.pan.setValueAtTime(currentPan, spatialAudioCtx.currentTime);
                    }
                } catch (e) {}
            }

            // Direct HTML Audio Element Volume & 3D attenuation
            if (currentTtsAudio) {
                currentTtsAudio.volume = Math.max(0, Math.min(1, baseTtsVolume * currentDistVolume));
            }
            if (mediaAudio) {
                mediaAudio.volume = Math.max(0, Math.min(1, baseMediaVolume * currentDistVolume));
            }

            // Direct YouTube iFrame 3D volume attenuation
            const ytContainer = document.getElementById('hidden-yt-player');
            if (ytContainer) {
                const iframe = ytContainer.querySelector('iframe');
                if (iframe && iframe.contentWindow) {
                    const ytVol = Math.round(currentDistVolume * 100);
                    iframe.contentWindow.postMessage(JSON.stringify({
                        event: 'command',
                        func: 'setVolume',
                        args: [ytVol]
                    }), '*');
                    if (currentDistVolume <= 0.01) {
                        iframe.contentWindow.postMessage(JSON.stringify({
                            event: 'command',
                            func: 'mute',
                            args: []
                        }), '*');
                    } else {
                        iframe.contentWindow.postMessage(JSON.stringify({
                            event: 'command',
                            func: 'unMute',
                            args: []
                        }), '*');
                    }
                }
            }
        };

        // Free AI Brain & Natural Audio TTS Engine with 3D Spatial Audio
        let currentTtsAudio = null;

        const playNaturalVoiceTTS = (text) => {
            if (!text || text === '') return;
            initSpatialAudio();
            try {
                if (currentTtsAudio) {
                    currentTtsAudio.pause();
                    currentTtsAudio = null;
                }
                const ttsLang = (config.value && config.value.language) ? config.value.language.toLowerCase() : 'en';
                const streamElementsVoiceMap = {
                    'en': 'Brian',
                    'tr': 'Filiz',
                    'de': 'Hans',
                    'fr': 'Mathieu',
                    'es': 'Enrique',
                    'it': 'Giorgio',
                    'pt': 'Cristiano',
                    'nl': 'Lotte',
                    'pl': 'Jacek',
                    'ru': 'Maxim',
                    'ar': 'Zayd',
                    'cs': 'Jan'
                };
                const voiceName = streamElementsVoiceMap[ttsLang] || 'Brian';
                const ttsUrl = `https://api.streamelements.com/kappa/v2/speech?voice=${voiceName}&text=${encodeURIComponent(text)}`;
                
                currentTtsAudio = new Audio(ttsUrl);
                currentTtsAudio.volume = Math.max(0, Math.min(1, baseTtsVolume * currentDistVolume));
                
                const playPromise = currentTtsAudio.play();
                if (playPromise !== undefined) {
                    playPromise.catch(e => {
                        const fallbackUrl = `https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=${ttsLang}&q=${encodeURIComponent(text)}`;
                        currentTtsAudio = new Audio(fallbackUrl);
                        currentTtsAudio.volume = Math.max(0, Math.min(1, baseTtsVolume * currentDistVolume));
                        currentTtsAudio.play().catch(err => {
                            if ('speechSynthesis' in window) {
                                window.speechSynthesis.cancel();
                                const utterance = new SpeechSynthesisUtterance(text);
                                const speechLangTagMap = {
                                    'tr': 'tr-TR', 'en': 'en-US', 'de': 'de-DE', 'fr': 'fr-FR',
                                    'es': 'es-ES', 'it': 'it-IT', 'pt': 'pt-PT', 'nl': 'nl-NL',
                                    'pl': 'pl-PL', 'ru': 'ru-RU', 'ar': 'ar-SA', 'cs': 'cs-CZ'
                                };
                                const speechLangTag = speechLangTagMap[ttsLang] || 'en-US';
                                utterance.lang = speechLangTag;
                                utterance.rate = 0.95;
                                utterance.pitch = 1.0;
                                utterance.volume = Math.max(0, Math.min(1, baseTtsVolume * currentDistVolume));
                                
                                const voices = window.speechSynthesis.getVoices();
                                const bestVoice = voices.find(v => v.lang.startsWith(ttsLang) && (v.name.includes('Natural') || v.name.includes('Google') || v.name.includes('Premium')));
                                if (bestVoice) utterance.voice = bestVoice;

                                window.speechSynthesis.speak(utterance);
                            }
                        });
                    });
                }
            } catch (e) {
                console.log('TTS Error:', e);
            }
        };

        const queryFreeAIBrain = (userPrompt, street) => {
            const inTripDialogues = [
                L('dialogue_intrip_1', "Listening to you sir, proceeding safely along our route."),
                L('dialogue_intrip_2', "Los Santos traffic looks quite smooth today. We will reach our target right on time."),
                L('dialogue_intrip_3', "Our smart LIDAR and radar system is constantly scanning for pedestrians and obstacles."),
                L('dialogue_intrip_4', "The city view is fantastic at this hour. Please relax and enjoy the ride.")
            ];
            const randomReply = inTripDialogues[Math.floor(Math.random() * inTripDialogues.length)];
            return randomReply;
        };

        // Driver Speech TTS & Subtitle HUD State
        const driverSpeech = ref({
            active: false,
            text: '',
            driverName: 'Niko Bellic'
        });
        let speechHideTimer = null;

        const speakText = (text, name) => {
            if (!text) return;
            
            driverSpeech.value = {
                active: true,
                text: text,
                driverName: name || config.value.driverName || 'Niko Bellic'
            };
            
            if (speechHideTimer) clearTimeout(speechHideTimer);
            const durationMs = Math.max(4500, Math.min(12000, text.length * 95));
            speechHideTimer = setTimeout(() => {
                driverSpeech.value.active = false;
            }, durationMs);

            // Play natural spoken Turkish voice with 3D Spatial Audio
            playNaturalVoiceTTS(text);
        };

        // Trip Background Audio / Stream Player
        let mediaAudio = null;

        const startTripMedia = (data) => {
            stopTripMedia();
            if (!data) return;
            initSpatialAudio();

            if (data.youtubeUrl && data.youtubeUrl.length > 5) {
                let videoId = '';
                const match = data.youtubeUrl.match(/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})/);
                if (match && match[1]) {
                    videoId = match[1];
                }
                if (videoId) {
                    let container = document.getElementById('hidden-yt-player');
                    if (!container) {
                        container = document.createElement('div');
                        container.id = 'hidden-yt-player';
                        container.style.cssText = 'position:fixed;top:-9999px;left:-9999px;width:1px;height:1px;pointer-events:none;';
                        document.body.appendChild(container);
                    }
                    container.innerHTML = `<iframe width="100" height="100" src="https://www.youtube.com/embed/${videoId}?autoplay=1&enablejsapi=1" frameborder="0" allow="autoplay"></iframe>`;
                }
            } else if (data.genre && data.genre !== 'Radio Off') {
                let streamUrl = '';
                if (data.genre === 'Lo-Fi Beats') {
                    streamUrl = 'https://stream.zeno.fm/f3wvbbqmdg8uv';
                } else if (data.genre === '80s Synthwave') {
                    streamUrl = 'https://stream.nightride.fm/synthwave.mp3';
                } else if (data.genre === 'Pop Hits') {
                    streamUrl = 'https://stream.zeno.fm/0r0xa792kwzuv';
                }
                if (streamUrl) {
                    try {
                        mediaAudio = new Audio(streamUrl);
                        mediaAudio.volume = Math.max(0, Math.min(1, baseMediaVolume * currentDistVolume));
                        mediaAudio.play().catch(e => console.log('Audio autoplay stream:', e));
                    } catch (e) {
                        console.log('Audio load error:', e);
                    }
                }
            }
        };

        const stopTripMedia = () => {
            if (mediaAudio) {
                mediaAudio.pause();
                mediaAudio.src = '';
                mediaAudio = null;
            }
            const container = document.getElementById('hidden-yt-player');
            if (container) {
                container.innerHTML = '';
            }
        };

        const selectedStyleData = computed(() => {
            const s = config.value && config.value.drivingStyles && config.value.drivingStyles[selectedStyle.value];
            return s || { label: 'Normal Sürüş' };
        });

        const meterStatusDisplay = computed(() => {
            const raw = meterStatus.value;
            if (raw === 'Hazır' || raw === 'status_ready' || raw === 'Ready') return L('status_ready', 'Ready');
            if (raw === 'Gidiliyor...' || raw === 'status_driving' || raw === 'Driving...') return L('status_driving', 'Driving...');
            if (raw === 'Harita İşareti Bekleniyor...' || raw === 'status_waiting_waypoint' || raw === 'Waiting for Waypoint...') return L('status_waiting_waypoint', 'Waiting for Waypoint...');
            if (raw === 'Ulaşıldı' || raw === 'status_arrived' || raw === 'Arrived') return L('status_arrived', 'Arrived');
            if (raw === 'İptal Edildi' || raw === 'status_cancelled' || raw === 'Cancelled') return L('status_cancelled', 'Cancelled');
            if (raw === 'Geliyor...' || raw === 'status_en_route' || raw === 'En Route...') return L('status_en_route', 'En Route...');
            return raw;
        });

        const meterStatusClass = computed(() => {
            const raw = meterStatus.value;
            if (raw === 'Gidiliyor...' || raw === 'status_driving' || raw === 'Driving...') return 'active';
            if (raw === 'Harita İşareti Bekleniyor...' || raw === 'status_waiting_waypoint' || raw === 'Waiting for Waypoint...' || raw === 'Geliyor...') return 'waiting';
            return '';
        });

        const postNUI = (endpoint, data = {}) => {
            const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'DepAITaxi';
            return fetch(`https://${resourceName}/${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data)
            }).catch(err => {
                console.log('NUI Fetch Fallback error:', err);
                return { json: async () => ({ success: true }) };
            });
        };

        const closeUI = () => {
            visible.value = false;
            postNUI('closeUI');
        };

        const selectDrivingStyle = (styleKey) => {
            selectedStyle.value = styleKey;
            postNUI('setDrivingStyle', { style: styleKey });
        };

        const selectVehicle = (vehId) => {
            selectedVehicle.value = vehId;
            config.value.vehicleModel = vehId;
        };

        const prevVehicle = () => {
            const currentIndex = vehicles.value.findIndex(v => v.id === selectedVehicle.value);
            const prevIndex = (currentIndex - 1 + vehicles.value.length) % vehicles.value.length;
            selectVehicle(vehicles.value[prevIndex].id);
        };

        const nextVehicle = () => {
            const currentIndex = vehicles.value.findIndex(v => v.id === selectedVehicle.value);
            const nextIndex = (currentIndex + 1) % vehicles.value.length;
            selectVehicle(vehicles.value[nextIndex].id);
        };

        const getStackedCardStyle = (index) => {
            const activeIndex = vehicles.value.findIndex(v => v.id === selectedVehicle.value);
            const diff = index - (activeIndex >= 0 ? activeIndex : 0);

            if (diff === 0) {
                return {
                    transform: 'translateX(30px) translateY(0px) scale(1)',
                    zIndex: 30,
                    opacity: 1,
                    filter: 'brightness(1)'
                };
            } else if (diff > 0) {
                const offsetX = 30 + diff * 95;
                const scale = 1 - diff * 0.07;
                const zIndex = 30 - diff * 5;
                const brightness = 1 - diff * 0.28;
                return {
                    transform: `translateX(${offsetX}px) translateY(${diff * 8}px) scale(${scale})`,
                    zIndex: zIndex,
                    opacity: 0.85,
                    filter: `brightness(${brightness})`
                };
            } else {
                const offsetX = 30 + diff * 95;
                const absDiff = Math.abs(diff);
                const scale = 1 - absDiff * 0.07;
                const zIndex = 30 - absDiff * 5;
                const brightness = 1 - absDiff * 0.28;
                return {
                    transform: `translateX(${offsetX}px) translateY(${absDiff * 8}px) scale(${scale})`,
                    zIndex: zIndex,
                    opacity: 0.85,
                    filter: `brightness(${brightness})`
                };
            }
        };

        const confirmCallTaxi = () => {
            if (activeTrip.value) return;

            postNUI('callTaxi', {
                style: selectedStyle.value,
                vehicleModel: selectedVehicle.value,
                preferences: preferences.value,
                subPreferences: {
                    ...subPreferences.value,
                    youtubeUrl: youtubeUrl.value
                }
            }).then(res => res.json()).then(data => {
                if (data.success) {
                    activeTrip.value = true;
                    meterStatus.value = 'Geliyor...';
                    visible.value = false;
                }
            });
        };

        const cancelTrip = () => {
            postNUI('cancelTrip');
            stopTripMedia();
            activeTrip.value = false;
            meterStatus.value = 'İptal Edildi';
            liveFare.value = config.value.baseFare.toFixed(2);
            liveDistance.value = '0.00';
        };

        const copyPosFromUI = () => {
            postNUI('copyCurrentPos');
        };

        const tabletTouchVisible = ref(false);
        const cabinWindows = ref(false);
        const cabinLight = ref(false);

        const isListening = ref(false);
        const isThinking = ref(false);
        const voiceTranscript = ref('');
        const voiceModalVisible = ref(false);
        const voiceInputText = ref('');
        let recognition = null;
        let mediaRecorder = null;
        let audioChunks = [];
        let micStream = null;

        // First Boarding Interactive Window Question (Camları açayım mı?)
        const boardingQuestion = ref({
            active: false,
            text: 'Araç camlarını açmamı ister misiniz?'
        });

        const answerBoardingQuestion = (action) => {
            boardingQuestion.value.active = false;
            const root = document.getElementById('ai-boarding-dialog-root');
            if (root) {
                root.classList.remove('visible');
                root.classList.add('hidden');
            }
            let actionStr = 'close';
            if (typeof action === 'boolean') {
                actionStr = action ? 'windows' : 'close';
            } else if (typeof action === 'string' && action.trim() !== '') {
                actionStr = action.trim();
            }
            postNUI('boardingQuestionAnswer', { answer: actionStr });
        };

        const voiceChips = ref([
            { label: '⚡ Hızlı Sür', prompt: 'Hızlı sür' },
            { label: '🛡️ Sakin Sür', prompt: 'Sakin ve güvenli sür' },
            { label: '🪟 Camları Aç', prompt: 'Camları aç' },
            { label: '🪟 Camları Kapat', prompt: 'Camları kapat' },
            { label: '💡 İç Işık', prompt: 'İç kabin ışığını aç' },
            { label: '🎵 Lo-Fi Beats', prompt: 'Lo-Fi radyo yayını aç' },
            { label: '🎵 80s Synthwave', prompt: 'Synthwave müzik aç' },
            { label: '📍 Neredeyiz?', prompt: 'Şu an neredeyiz konumu söyle' },
            { label: '🗣️ Merhaba Niko', prompt: 'Merhaba Niko nasılsın?' },
            { label: '😄 Bir Fıkra Anlat', prompt: 'Bize kısa komik bir fıkra anlat' },
            { label: '🛑 Sağa Çek', prompt: 'Sağa çek yolculuğu durdur' }
        ]);

        const submitVoicePromptText = (text) => {
            const promptToSend = text || voiceInputText.value;
            if (!promptToSend || !promptToSend.trim()) return;
            voiceInputText.value = '';
            voiceModalVisible.value = false;
            postNUI('closeVoiceModal');
            processTranscribedPrompt(promptToSend.trim());
        };

        const closeVoiceModal = () => {
            voiceModalVisible.value = false;
            postNUI('closeVoiceModal');
        };

        // Real Microphone Audio Recording & Speech-To-Text Pipeline
        const startVoiceRecognition = async () => {
            if (isListening.value) {
                stopVoiceRecognition();
                return;
            }

            voiceTranscript.value = 'Dinleniyor...';
            isListening.value = true;

            // 1. Try Real HTML5 Microphone Stream (MediaRecorder for Custom Backend STT)
            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                try {
                    micStream = await navigator.mediaDevices.getUserMedia({ audio: true });
                    audioChunks = [];
                    mediaRecorder = new MediaRecorder(micStream);

                    mediaRecorder.ondataavailable = (e) => {
                        if (e.data && e.data.size > 0) {
                            audioChunks.push(e.data);
                        }
                    };

                    mediaRecorder.onstop = () => {
                        isListening.value = false;
                        const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
                        const reader = new FileReader();
                        reader.readAsDataURL(audioBlob);
                        reader.onloadend = () => {
                            const base64Audio = reader.result.split(',')[1];
                            processRecordedAudioSTT(base64Audio, audioBlob);
                        };

                        if (micStream) {
                            micStream.getTracks().forEach(t => t.stop());
                            micStream = null;
                        }
                    };

                    mediaRecorder.start();
                    return;
                } catch (e) {
                    console.log('MediaRecorder mic permission / access:', e);
                }
            }

            // 2. Web Speech Recognition API Fallback
            if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
                const SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
                recognition = new SpeechRec();
                recognition.lang = 'tr-TR';
                recognition.continuous = false;
                recognition.interimResults = true;

                recognition.onresult = (event) => {
                    let currentText = '';
                    for (let i = 0; i < event.results.length; i++) {
                        currentText += event.results[i][0].transcript;
                    }
                    voiceTranscript.value = currentText;

                    if (event.results[0].isFinal) {
                        isListening.value = false;
                        if (currentText && currentText.trim().length > 0) {
                            processTranscribedPrompt(currentText.trim());
                        }
                    }
                };

                recognition.onerror = () => {
                    isListening.value = false;
                    voiceModalVisible.value = true;
                };

                recognition.onend = () => {
                    isListening.value = false;
                };

                try {
                    recognition.start();
                    return;
                } catch (e) {
                    isListening.value = false;
                }
            }

            // 3. If neither works, open interactive Voice Modal
            isListening.value = false;
            voiceModalVisible.value = true;
        };

        const stopVoiceRecognition = () => {
            if (mediaRecorder && mediaRecorder.state === 'recording') {
                mediaRecorder.stop();
            } else if (recognition) {
                try { recognition.stop(); } catch(e) {}
                isListening.value = false;
            } else {
                isListening.value = false;
            }
        };

        const processRecordedAudioSTT = async (base64Audio, audioBlob) => {
            isThinking.value = false;
        };

        const processTranscribedPrompt = async (userSpeech) => {
            if (!userSpeech || !userSpeech.trim()) return;
            const prompt = userSpeech.toLowerCase().trim();
            voiceTranscript.value = userSpeech;

            if (prompt.includes('cam') || prompt.includes('pencere') || prompt.includes('window')) {
                triggerCabinAction('windows');
                const reply = L('windows_opened_speech', "Rolling down the windows right away sir, enjoy your ride.");
                speakText(reply, config.value.driverName || 'Niko Bellic');
                postNUI('triggerSpeechFromNUI', { text: reply, driverName: config.value.driverName || 'Niko Bellic' });
                return;
            }

            if (prompt.includes('ışık') || prompt.includes('isik') || prompt.includes('kabin') || prompt.includes('light')) {
                triggerCabinAction('light');
                const reply = L('light_open_notify', "Turning on the interior cabin lighting sir.");
                speakText(reply, config.value.driverName || 'Niko Bellic');
                postNUI('triggerSpeechFromNUI', { text: reply, driverName: config.value.driverName || 'Niko Bellic' });
                return;
            }

            if (prompt.includes('hızlı') || prompt.includes('hizli') || prompt.includes('acele') || prompt.includes('sollama') || prompt.includes('solla') || prompt.includes('fast') || prompt.includes('speed') || prompt.includes('faster')) {
                triggerCabinAction('fast');
                const reply = L('turbo_speech', "Stepping on the gas sir! Accelerating and overtaking!");
                speakText(reply, config.value.driverName || 'Niko Bellic');
                postNUI('triggerSpeechFromNUI', { text: reply, driverName: config.value.driverName || 'Niko Bellic' });
                return;
            }

            if (prompt.includes('sakin') || prompt.includes('yavaş') || prompt.includes('yavas') || prompt.includes('slow') || prompt.includes('cautious')) {
                triggerCabinAction('cautious');
                const reply = L('cautious_speech', "Understood sir, switching to smooth and cautious driving mode.");
                speakText(reply, config.value.driverName || 'Niko Bellic');
                postNUI('triggerSpeechFromNUI', { text: reply, driverName: config.value.driverName || 'Niko Bellic' });
                return;
            }

            if (prompt.includes('dur') || prompt.includes('sağa çek') || prompt.includes('saga cek') || prompt.includes('durdur') || prompt.includes('stop') || prompt.includes('pull over')) {
                triggerCabinAction('stop');
                const reply = L('stop_speech', "Pulling over and stopping safely right away, sir.");
                speakText(reply, config.value.driverName || 'Niko Bellic');
                postNUI('triggerSpeechFromNUI', { text: reply, driverName: config.value.driverName || 'Niko Bellic' });
                return;
            }

            const customDialogues = (config.value && config.value.AIAssistantRules && config.value.AIAssistantRules.CustomDialogues) || {};
            let matchedResponse = null;
            let matchedAction = null;

            for (const key in customDialogues) {
                const item = customDialogues[key];
                if (item && item.keywords && Array.isArray(item.keywords)) {
                    for (const kw of item.keywords) {
                        if (prompt.includes(kw.toLowerCase())) {
                            matchedResponse = item.response;
                            matchedAction = item.action || null;
                            break;
                        }
                    }
                }
                if (matchedResponse) break;
            }

            if (matchedAction) {
                triggerCabinAction(matchedAction);
            }

            if (matchedResponse) {
                if (matchedResponse.includes('%s')) {
                    matchedResponse = matchedResponse.replace('%s', fsdSim.value.streetName || 'Los Santos');
                }
                speakText(matchedResponse, config.value.driverName || 'Niko Bellic');
                postNUI('triggerSpeechFromNUI', { text: matchedResponse, driverName: config.value.driverName || 'Niko Bellic' });
                return;
            }

            const fallbackReply = queryFreeAIBrain(userSpeech, fsdSim.value.streetName || 'Los Santos');
            if (fallbackReply) {
                speakText(fallbackReply, config.value.driverName || 'Niko Bellic');
                postNUI('triggerSpeechFromNUI', { text: fallbackReply, driverName: config.value.driverName || 'Niko Bellic' });
            }
        };

        const closeTabletTouch = () => {
            tabletTouchVisible.value = false;
            fetch(`https://${GetParentResourceName()}/closeTabletTouch`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            }).catch(e => {});
        };

        const triggerCabinAction = (type) => {
            fetch(`https://${GetParentResourceName()}/cabinAction`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ action: type })
            }).catch(e => {});
        };

        onMounted(() => {
            startFSDSimulation();

            window.addEventListener('message', (event) => {
                const item = event.data;
                if (!item) return;

                if (item.action === 'UPDATE_3D_AUDIO_SPATIAL') {
                    update3DSpatialAudio(item.data);
                } else if (item.action === 'START_VOICE_RECORDING') {
                    startVoiceRecognition();
                } else if (item.action === 'OPEN_VOICE_MODAL') {
                    voiceModalVisible.value = true;
                    voiceInputText.value = '';
                } else if (item.action === 'SHOW_BOARDING_QUESTION') {
                    boardingQuestion.value.active = true;
                    if (item.data && item.data.question) {
                        boardingQuestion.value.text = item.data.question;
                    }
                } else if (item.action === 'HIDE_BOARDING_QUESTION') {
                    boardingQuestion.value.active = false;
                } else if (item.action === 'PROCESS_DYNAMIC_AI_PROMPT') {
                    if (item.data && item.data.userPrompt) {
                        processTranscribedPrompt(item.data.userPrompt);
                    }
                } else if (item.action === 'UPDATE_TELEMETRY') {
                    lastTelemetryTime = Date.now();
                    const tele = item.data;
                    fsdSim.value.speedKMH = tele.speedKMH;
                    fsdSim.value.isDriving = tele.isDriving;
                    fsdSim.value.isLiveFiveM = true;

                    // Match steering angle to Bezier curve turn
                    if (tele.steeringAngle < -8.0) {
                        fsdSim.value.roadCurve = 'left';
                        fsdSim.value.showTrafficLight = false;
                        fsdSim.value.actionNotice = 'REAL-TIME FIVE M • LEFT TURN';
                        Object.assign(fsdSim.value, leftTurnRoad);
                    } else if (tele.steeringAngle > 8.0) {
                        fsdSim.value.roadCurve = 'right';
                        fsdSim.value.showTrafficLight = false;
                        fsdSim.value.actionNotice = 'REAL-TIME FIVE M • RIGHT TURN';
                        Object.assign(fsdSim.value, rightTurnRoad);
                    } else {
                        fsdSim.value.roadCurve = 'none';
                        fsdSim.value.actionNotice = tele.isDriving ? 'REAL-TIME FIVE M • FSD ONLINE' : '🔴 VEHICLE STOPPED';
                        Object.assign(fsdSim.value, straightRoad);
                        if (!tele.isDriving) {
                            fsdSim.value.trafficLight = 'red';
                            fsdSim.value.showTrafficLight = true;
                        } else {
                            fsdSim.value.trafficLight = 'green';
                            fsdSim.value.showTrafficLight = false;
                        }
                    }
                } else if (item.action === 'OPEN_UI' || item.action === 'OPEN_TAXI_UI') {
                    if (item.data) {
                        if (item.data.config) config.value = { ...config.value, ...item.data.config };
                        if (item.data.defaultStyle) selectedStyle.value = item.data.defaultStyle;
                        if (item.data.defaultVehicle) selectedVehicle.value = item.data.defaultVehicle;
                        if (item.data.activeTrip !== undefined) activeTrip.value = item.data.activeTrip;
                    }
                    currentScreen.value = 'welcome';
                    visible.value = true;
                } else if (item.action === 'CLOSE_UI') {
                    visible.value = false;
                } else if (item.action === 'OPEN_TABLET_TOUCH') {
                    tabletTouchVisible.value = true;
                    if (item.data) {
                        if (item.data.windows !== undefined) cabinWindows.value = item.data.windows;
                        if (item.data.light !== undefined) cabinLight.value = item.data.light;
                    }
                } else if (item.action === 'CLOSE_TABLET_TOUCH') {
                    tabletTouchVisible.value = false;
                } else if (item.action === 'UPDATE_CABIN_CONTROLS') {
                    if (item.data) {
                        if (item.data.windows !== undefined) cabinWindows.value = item.data.windows;
                        if (item.data.light !== undefined) cabinLight.value = item.data.light;
                    }
                } else if (item.action === 'SET_IN_CAR_HUD') {
                    if (item.data) {
                        inCarHUD.value = false;
                        if (item.data.fare) liveFare.value = item.data.fare;
                        if (item.data.distanceKM) liveDistance.value = item.data.distanceKM;
                        if (item.data.status) meterStatus.value = item.data.status;
                        if (item.data.preferences) preferences.value = { ...preferences.value, ...item.data.preferences };
                        if (item.data.subPreferences) subPreferences.value = { ...subPreferences.value, ...item.data.subPreferences };
                    }
                } else if (item.action === 'UPDATE_TAXIMETER') {
                    if (item.data) {
                        liveDistance.value = item.data.distanceKM || liveDistance.value;
                        liveFare.value = item.data.fare || liveFare.value;
                        meterStatus.value = item.data.status || meterStatus.value;
                        if (item.data.drivingStyle) selectedStyle.value = item.data.drivingStyle;

                        if (meterStatus.value === 'Ulaşıldı' || meterStatus.value === 'İptal Edildi') {
                            activeTrip.value = false;
                            tabletTouchVisible.value = false;
                            stopTripMedia();
                        } else {
                            activeTrip.value = true;
                        }
                    }
                } else if (item.action === 'AI_DRIVER_SPEAK') {
                    if (item.data) {
                        speakText(item.data.text, item.data.driverName);
                    }
                } else if (item.action === 'START_VOICE_INPUT') {
                    startVoiceRecognition();
                } else if (item.action === 'START_TRIP_MEDIA') {
                    startTripMedia(item.data);
                } else if (item.action === 'STOP_TRIP_MEDIA') {
                    stopTripMedia();
                }
            });

            window.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    const root = document.getElementById('ai-boarding-dialog-root');
                    if (root && root.classList.contains('visible')) {
                        root.classList.remove('visible');
                        root.classList.add('hidden');
                        postNUI('boardingQuestionAnswer', { answer: 'close' });
                    } else if (voiceModalVisible.value) {
                        closeVoiceModal();
                    } else if (tabletTouchVisible.value) {
                        closeTabletTouch();
                    } else if (visible.value) {
                        closeUI();
                    }
                }
            });
        });

        onUnmounted(() => {
            if (simTimer) clearInterval(simTimer);
            stopTripMedia();
        });

        return {
            L,
            visible,
            currentScreen,
            config,
            selectedVehicle,
            vehicles,
            toggleFavorite,
            activeTrip,
            inCarHUD,
            tabletTouchVisible,
            cabinWindows,
            cabinLight,
            triggerCabinAction,
            closeTabletTouch,
            meterStatus,
            meterStatusDisplay,
            meterStatusClass,
            liveDistance,
            liveFare,
            selectedStyle,
            preferences,
            subPreferences,
            youtubeUrl,
            fsdSim,
            driverSpeech,
            speakText,
            isListening,
            voiceTranscript,
            voiceModalVisible,
            voiceInputText,
            isThinking,
            voiceChips,
            submitVoicePromptText,
            closeVoiceModal,
            startVoiceRecognition,
            playCustomYouTube,
            togglePreference,
            closeUI,
            selectDrivingStyle,
            selectVehicle,
            prevVehicle,
            nextVehicle,
            selectedVehicleData,
            selectedStyleData,
            getStackedCardStyle,
            confirmCallTaxi,
            cancelTrip,
            copyPosFromUI,
            musicGenres,
            quietTypes,
            routeTypes,
            vipColors,
            selectedVipColorObj,
            boardingQuestion,
            answerBoardingQuestion
        };
    }
}).mount('#app');
