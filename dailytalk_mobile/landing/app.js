(() => {
  "use strict";
  const localizedPageDirs={"pt-PT":"","en-US":"en/","es-ES":"es/","fr-FR":"fr/","it-IT":"it/","de-DE":"de/"};
  const updateInternalLinks=(locale)=>{
    const dir=localizedPageDirs[locale]||"";
    const map={navHow:"how-it-works.html",navErasmus:"erasmus.html",navResources:"resources.html",navCommunity:"community.html",navAbout:"about.html"};
    Object.entries(map).forEach(([key,file])=>{
      const el=document.querySelector(`[data-i18n="${key}"]`);
      if(el) el.href=`/landing/${dir}${file}`;
    });
  };

  const translations = {
    "pt-PT": {
      code:"PT", navHome:"Início",navHow:"Como funciona",navErasmus:"Erasmus+",navResources:"Recursos",navCommunity:"Comunidade",navAbout:"Sobre",
      login:"Entrar",register:"Criar conta",testNow:"Testar agora",learnMore:"Saber mais",eyebrow:"PARA ESCOLAS E PROGRAMAS ERASMUS+",
      heroLine1:"Prepara-te para",heroLine2:"falar no ",heroAccent:"mundo real",
      heroLead:"Aprende expressões e diálogos úteis para o teu dia a dia em mobilidade escolar Erasmus+, pratica com situações reais e ganha confiança para comunicar em qualquer momento da tua viagem.",
      benefitFree:"Gratuito para começar",benefitOffline:"Funciona offline",benefitDevices:"Em todos os teus dispositivos",
      scribbleLeft:"Aprende<br>quando e onde<br>quiseres!",scribbleRight:"Mais do que<br>aprender uma língua.<br>É viver novas<br>experiências.",
      howTitle:"Como o DailyTalk.pt ajuda",
      featureDialogues:"Diálogos reais",featureDialoguesText:"Situações do dia a dia da tua mobilidade",
      featurePaths:"Percursos adaptados",featurePathsText:"Foca-te no que precisas de aprender",
      featureOffline:"Funciona offline",featureOfflineText:"Pratica mesmo sem internet",
      featureSync:"Sincroniza o teu progresso",featureSyncText:"Telemóvel, tablet e computador",
      featureCommunity:"Conteúdo orientado por situações reais",featureCommunityText:"Aprende o que é útil antes e durante a mobilidade",
      situationsTitle:"Situações reais, para a tua vida de estudante",
      situationsLead:"Do aeroporto à escola, passando pelo alojamento, transportes, refeições e muito mais. Tudo o que precisas para te sentires preparado.",
      viewAll:"Ver todos os temas →",airport:"No aeroporto",airportText:"Chegadas, check-in e imigração",
      accommodation:"Alojamento",accommodationText:"Família anfitriã, residência, regras",
      school:"Na escola",schoolText:"Colegas, professores e rotinas",transport:"Transportes",transportText:"Autocarros, comboios e bilhetes",
      food:"Comida",foodText:"Restaurantes, menus e pedidos",social:"Vida social",socialText:"Amigos, convites e atividades",
      resourceKicker:"APRENDER PARA USAR",resourceTitle:"Comunicação prática para momentos que realmente acontecem.",
      resourceText:"O percurso combina vocabulário, diálogo, fala, quiz e revisão para preparar o aluno antes e durante a mobilidade escolar.",
      communityTitle:"Aprender com autonomia, sem perder o percurso.",
      communityText:"O aluno pode praticar de formas diferentes e continuar a evoluir. O progresso é local e imediato; quando existe ligação, os dispositivos voltam a convergir.",
      aboutTitle:"DailyTalk.pt",aboutText:"Uma plataforma educativa orientada à comunicação prática de jovens em mobilidade escolar Erasmus+, concebida para funcionar também em condições de conectividade limitada.",
      menuOpen:"Abrir menu"
    },
    "en-US": {
      code:"EN",navHome:"Home",navHow:"How it works",navErasmus:"Erasmus+",navResources:"Resources",navCommunity:"Community",navAbout:"About",
      login:"Sign in",register:"Create account",testNow:"Try now",learnMore:"Learn more",eyebrow:"FOR SCHOOLS AND ERASMUS+ PROGRAMMES",
      heroLine1:"Get ready to",heroLine2:"speak in the ",heroAccent:"real world",
      heroLead:"Learn useful expressions and dialogues for everyday school mobility, practise real situations and gain confidence to communicate throughout your Erasmus+ journey.",
      benefitFree:"Free to get started",benefitOffline:"Works offline",benefitDevices:"Across your devices",
      scribbleLeft:"Learn<br>whenever and<br>wherever!",scribbleRight:"More than<br>learning a language.<br>Live new<br>experiences.",
      howTitle:"How DailyTalk.pt helps",featureDialogues:"Real dialogues",featureDialoguesText:"Everyday situations from your mobility",
      featurePaths:"Adapted paths",featurePathsText:"Focus on what you need to learn",featureOffline:"Works offline",featureOfflineText:"Practise even without internet",
      featureSync:"Sync your progress",featureSyncText:"Phone, tablet and computer",featureCommunity:"Real-life content",featureCommunityText:"Learn what is useful before and during mobility",
      situationsTitle:"Real situations for student life",situationsLead:"From the airport to school, including accommodation, transport, meals and much more. Everything you need to feel prepared.",
      viewAll:"View all topics →",airport:"At the airport",airportText:"Arrivals, check-in and immigration",accommodation:"Accommodation",accommodationText:"Host family, residence, rules",
      school:"At school",schoolText:"Classmates, teachers and routines",transport:"Transport",transportText:"Buses, trains and tickets",food:"Food",foodText:"Restaurants, menus and ordering",
      social:"Social life",socialText:"Friends, invitations and activities",resourceKicker:"LEARN TO USE IT",resourceTitle:"Practical communication for moments that really happen.",
      resourceText:"The path combines vocabulary, dialogue, speaking, quizzes and review to prepare students before and during school mobility.",
      communityTitle:"Learn with autonomy, without losing your path.",communityText:"Students can practise in different ways and keep progressing. Progress is local and immediate; when online, devices converge again.",
      aboutTitle:"DailyTalk.pt",aboutText:"An educational platform focused on practical communication for young people in Erasmus+ school mobility, designed to keep working with limited connectivity.",
      menuOpen:"Open menu"
    },
    "es-ES": {
      code:"ES",navHome:"Inicio",navHow:"Cómo funciona",navErasmus:"Erasmus+",navResources:"Recursos",navCommunity:"Comunidad",navAbout:"Sobre",
      login:"Entrar",register:"Crear cuenta",testNow:"Probar ahora",learnMore:"Saber más",eyebrow:"PARA CENTROS EDUCATIVOS Y PROGRAMAS ERASMUS+",
      heroLine1:"Prepárate para",heroLine2:"hablar en el ",heroAccent:"mundo real",
      heroLead:"Aprende expresiones y diálogos útiles para la movilidad escolar Erasmus+, practica situaciones reales y gana confianza para comunicarte durante tu viaje.",
      benefitFree:"Gratis para empezar",benefitOffline:"Funciona sin conexión",benefitDevices:"En todos tus dispositivos",
      scribbleLeft:"Aprende<br>cuando y donde<br>quieras!",scribbleRight:"Más que<br>aprender un idioma.<br>Es vivir nuevas<br>experiencias.",
      howTitle:"Cómo ayuda DailyTalk.pt",featureDialogues:"Diálogos reales",featureDialoguesText:"Situaciones cotidianas de tu movilidad",
      featurePaths:"Rutas adaptadas",featurePathsText:"Céntrate en lo que necesitas aprender",featureOffline:"Funciona sin conexión",featureOfflineText:"Practica incluso sin internet",
      featureSync:"Sincroniza tu progreso",featureSyncText:"Móvil, tableta y ordenador",featureCommunity:"Contenido para situaciones reales",featureCommunityText:"Aprende lo útil antes y durante la movilidad",
      situationsTitle:"Situaciones reales para tu vida de estudiante",situationsLead:"Del aeropuerto a la escuela, pasando por el alojamiento, el transporte, las comidas y mucho más.",
      viewAll:"Ver todos los temas →",airport:"En el aeropuerto",airportText:"Llegadas, check-in e inmigración",accommodation:"Alojamiento",accommodationText:"Familia anfitriona, residencia, normas",
      school:"En la escuela",schoolText:"Compañeros, profesores y rutinas",transport:"Transportes",transportText:"Autobuses, trenes y billetes",food:"Comida",foodText:"Restaurantes, menús y pedidos",
      social:"Vida social",socialText:"Amigos, invitaciones y actividades",resourceKicker:"APRENDER PARA USAR",resourceTitle:"Comunicación práctica para momentos que ocurren de verdad.",
      resourceText:"El recorrido combina vocabulario, diálogo, habla, cuestionarios y repaso para preparar al alumno antes y durante la movilidad escolar.",
      communityTitle:"Aprende con autonomía sin perder el recorrido.",communityText:"El alumno puede practicar de distintas formas y seguir avanzando. El progreso es local e inmediato; al volver la conexión, los dispositivos convergen.",
      aboutTitle:"DailyTalk.pt",aboutText:"Una plataforma educativa para la comunicación práctica de jóvenes en movilidad escolar Erasmus+, diseñada también para conectividad limitada.",
      menuOpen:"Abrir menú"
    },
    "fr-FR": {
      code:"FR",navHome:"Accueil",navHow:"Comment ça marche",navErasmus:"Erasmus+",navResources:"Ressources",navCommunity:"Communauté",navAbout:"À propos",
      login:"Se connecter",register:"Créer un compte",testNow:"Essayer",learnMore:"En savoir plus",eyebrow:"POUR LES ÉCOLES ET LES PROGRAMMES ERASMUS+",
      heroLine1:"Prépare-toi à",heroLine2:"parler dans le ",heroAccent:"monde réel",
      heroLead:"Apprends des expressions et des dialogues utiles pour la mobilité scolaire Erasmus+, entraîne-toi avec des situations réelles et gagne en confiance.",
      benefitFree:"Gratuit pour commencer",benefitOffline:"Fonctionne hors ligne",benefitDevices:"Sur tous tes appareils",
      scribbleLeft:"Apprends<br>quand et où<br>tu veux !",scribbleRight:"Plus que<br>l'apprentissage d'une langue.<br>De nouvelles<br>expériences.",
      howTitle:"Comment DailyTalk.pt t'aide",featureDialogues:"Dialogues réels",featureDialoguesText:"Situations quotidiennes de ta mobilité",
      featurePaths:"Parcours adaptés",featurePathsText:"Concentre-toi sur ce que tu dois apprendre",featureOffline:"Fonctionne hors ligne",featureOfflineText:"Entraîne-toi même sans internet",
      featureSync:"Synchronise ta progression",featureSyncText:"Téléphone, tablette et ordinateur",featureCommunity:"Contenu pour des situations réelles",featureCommunityText:"Apprends ce qui est utile avant et pendant la mobilité",
      situationsTitle:"Des situations réelles pour ta vie d'élève",situationsLead:"De l'aéroport à l'école, en passant par l'hébergement, les transports, les repas et bien plus encore.",
      viewAll:"Voir tous les thèmes →",airport:"À l'aéroport",airportText:"Arrivées, enregistrement et immigration",accommodation:"Hébergement",accommodationText:"Famille d'accueil, résidence, règles",
      school:"À l'école",schoolText:"Camarades, professeurs et routines",transport:"Transports",transportText:"Bus, trains et billets",food:"Repas",foodText:"Restaurants, menus et commandes",
      social:"Vie sociale",socialText:"Amis, invitations et activités",resourceKicker:"APPRENDRE POUR UTILISER",resourceTitle:"Une communication pratique pour des moments qui arrivent vraiment.",
      resourceText:"Le parcours combine vocabulaire, dialogue, expression orale, quiz et révision pour préparer l'élève avant et pendant la mobilité scolaire.",
      communityTitle:"Apprendre avec autonomie sans perdre son parcours.",communityText:"L'élève peut s'entraîner de différentes façons et continuer à progresser. La progression est locale et immédiate ; une fois connecté, les appareils convergent.",
      aboutTitle:"DailyTalk.pt",aboutText:"Une plateforme éducative axée sur la communication pratique des jeunes en mobilité scolaire Erasmus+, conçue aussi pour une connectivité limitée.",
      menuOpen:"Ouvrir le menu"
    },
    "it-IT": {
      code:"IT",navHome:"Home",navHow:"Come funziona",navErasmus:"Erasmus+",navResources:"Risorse",navCommunity:"Comunità",navAbout:"Informazioni",
      login:"Accedi",register:"Crea account",testNow:"Prova ora",learnMore:"Scopri di più",eyebrow:"PER SCUOLE E PROGRAMMI ERASMUS+",
      heroLine1:"Preparati a",heroLine2:"parlare nel ",heroAccent:"mondo reale",
      heroLead:"Impara espressioni e dialoghi utili per la mobilità scolastica Erasmus+, esercitati con situazioni reali e acquisisci sicurezza nella comunicazione.",
      benefitFree:"Gratis per iniziare",benefitOffline:"Funziona offline",benefitDevices:"Su tutti i tuoi dispositivi",
      scribbleLeft:"Impara<br>quando e dove<br>vuoi!",scribbleRight:"Più che<br>imparare una lingua.<br>Vivi nuove<br>esperienze.",
      howTitle:"Come aiuta DailyTalk.pt",featureDialogues:"Dialoghi reali",featureDialoguesText:"Situazioni quotidiane della mobilità",
      featurePaths:"Percorsi adattati",featurePathsText:"Concentrati su ciò che devi imparare",featureOffline:"Funziona offline",featureOfflineText:"Esercitati anche senza internet",
      featureSync:"Sincronizza i progressi",featureSyncText:"Telefono, tablet e computer",featureCommunity:"Contenuti per situazioni reali",featureCommunityText:"Impara ciò che serve prima e durante la mobilità",
      situationsTitle:"Situazioni reali per la tua vita da studente",situationsLead:"Dall'aeroporto alla scuola, passando per alloggio, trasporti, pasti e molto altro.",
      viewAll:"Vedi tutti i temi →",airport:"In aeroporto",airportText:"Arrivi, check-in e immigrazione",accommodation:"Alloggio",accommodationText:"Famiglia ospitante, residenza, regole",
      school:"A scuola",schoolText:"Compagni, insegnanti e routine",transport:"Trasporti",transportText:"Autobus, treni e biglietti",food:"Cibo",foodText:"Ristoranti, menu e ordinazioni",
      social:"Vita sociale",socialText:"Amici, inviti e attività",resourceKicker:"IMPARARE PER USARE",resourceTitle:"Comunicazione pratica per momenti che accadono davvero.",
      resourceText:"Il percorso combina vocabolario, dialogo, parlato, quiz e ripasso per preparare lo studente prima e durante la mobilità scolastica.",
      communityTitle:"Impara con autonomia senza perdere il percorso.",communityText:"Lo studente può esercitarsi in modi diversi e continuare a progredire. I progressi sono locali e immediati; quando torna la connessione, i dispositivi convergono.",
      aboutTitle:"DailyTalk.pt",aboutText:"Una piattaforma educativa per la comunicazione pratica dei giovani in mobilità scolastica Erasmus+, progettata anche per connettività limitata.",
      menuOpen:"Apri menu"
    },
    "de-DE": {
      code:"DE",navHome:"Start",navHow:"So funktioniert es",navErasmus:"Erasmus+",navResources:"Ressourcen",navCommunity:"Community",navAbout:"Über",
      login:"Anmelden",register:"Konto erstellen",testNow:"Jetzt testen",learnMore:"Mehr erfahren",eyebrow:"FÜR SCHULEN UND ERASMUS+-PROGRAMME",
      heroLine1:"Bereite dich darauf vor,",heroLine2:"in der ",heroAccent:"realen Welt zu sprechen",
      heroLead:"Lerne nützliche Ausdrücke und Dialoge für deine Erasmus+-Schulmobilität, übe reale Situationen und gewinne Sicherheit beim Kommunizieren.",
      benefitFree:"Kostenlos starten",benefitOffline:"Funktioniert offline",benefitDevices:"Auf all deinen Geräten",
      scribbleLeft:"Lerne<br>wann und wo<br>du willst!",scribbleRight:"Mehr als<br>eine Sprache lernen.<br>Neue Erfahrungen<br>erleben.",
      howTitle:"So hilft DailyTalk.pt",featureDialogues:"Reale Dialoge",featureDialoguesText:"Alltagssituationen deiner Mobilität",
      featurePaths:"Angepasste Lernwege",featurePathsText:"Konzentriere dich auf das, was du brauchst",featureOffline:"Funktioniert offline",featureOfflineText:"Übe auch ohne Internet",
      featureSync:"Fortschritt synchronisieren",featureSyncText:"Handy, Tablet und Computer",featureCommunity:"Inhalte für reale Situationen",featureCommunityText:"Lerne, was vor und während der Mobilität wirklich nützlich ist",
      situationsTitle:"Reale Situationen für deinen Schulalltag",situationsLead:"Vom Flughafen bis zur Schule: Unterkunft, Verkehr, Mahlzeiten und vieles mehr.",
      viewAll:"Alle Themen ansehen →",airport:"Am Flughafen",airportText:"Ankunft, Check-in und Einreise",accommodation:"Unterkunft",accommodationText:"Gastfamilie, Wohnheim, Regeln",
      school:"In der Schule",schoolText:"Mitschüler, Lehrkräfte und Routinen",transport:"Verkehr",transportText:"Busse, Züge und Fahrkarten",food:"Essen",foodText:"Restaurants, Speisekarten und Bestellungen",
      social:"Soziales Leben",socialText:"Freunde, Einladungen und Aktivitäten",resourceKicker:"LERNEN, UM ES ZU NUTZEN",resourceTitle:"Praktische Kommunikation für Situationen, die wirklich passieren.",
      resourceText:"Der Lernweg verbindet Wortschatz, Dialog, Sprechen, Quiz und Wiederholung, um Schüler vor und während der Schulmobilität vorzubereiten.",
      communityTitle:"Selbstständig lernen, ohne den Lernweg zu verlieren.",communityText:"Schüler können auf unterschiedliche Weise üben und weiterkommen. Der Fortschritt ist lokal und sofort; sobald eine Verbindung besteht, gleichen sich die Geräte wieder ab.",
      aboutTitle:"DailyTalk.pt",aboutText:"Eine Bildungsplattform für die praktische Kommunikation junger Menschen in Erasmus+-Schulmobilität, entwickelt auch für eingeschränkte Konnektivität.",
      menuOpen:"Menü öffnen"
    }
  };

  const flagByLocale = {
    "pt-PT":"/landing/assets/flags/pt.svg",
    "en-US":"/landing/assets/flags/en.svg",
    "es-ES":"/landing/assets/flags/es.svg",
    "fr-FR":"/landing/assets/flags/fr.svg",
    "it-IT":"/landing/assets/flags/it.svg",
    "de-DE":"/landing/assets/flags/de.svg"
  };

  const picker = document.querySelector(".language-picker");
  const pickerButton = picker?.querySelector(".language-button");
  const menu = picker?.querySelector(".language-menu");
  const navToggle = document.querySelector(".nav-toggle");
  const nav = document.querySelector(".main-nav");
  const heroTest = document.querySelector("[data-hero-test]");
  const stickyTest = document.querySelector("[data-sticky-test]");
  const mobileTest = document.querySelector("[data-mobile-test]");

  const normalizeLocale = (value) => {
    if (!value) return "pt-PT";
    const exact = Object.keys(translations).find(x => x.toLowerCase() === value.toLowerCase());
    if (exact) return exact;
    const language = value.slice(0,2).toLowerCase();
    return Object.keys(translations).find(x => x.slice(0,2).toLowerCase() === language) || "pt-PT";
  };

  const setLocale = (locale) => {
    locale = normalizeLocale(locale);
    const strings = translations[locale];
    document.documentElement.lang = locale;
    document.querySelectorAll("[data-i18n]").forEach(el => {
      const key = el.getAttribute("data-i18n");
      if (strings[key] != null) el.innerHTML = strings[key];
    });
    document.querySelectorAll("[data-i18n-aria]").forEach(el => {
      const key = el.getAttribute("data-i18n-aria");
      if (strings[key] != null) el.setAttribute("aria-label", strings[key]);
    });
    const flagEl = document.querySelector("[data-current-flag]");
    const codeEl = document.querySelector("[data-current-code]");
    if (flagEl) flagEl.setAttribute("src", flagByLocale[locale]);
    if (codeEl) codeEl.textContent = strings.code;
    document.querySelectorAll("[data-locale]").forEach(btn => {
      btn.setAttribute("aria-selected", btn.dataset.locale === locale ? "true" : "false");
    });
    localStorage.setItem("dailytalk.landing.locale", locale); updateInternalLinks(locale);
  };

  const saved = localStorage.getItem("dailytalk.landing.locale");
  const pageLocale = document.body.dataset.locale;
  const initialLocale = pageLocale || saved || navigator.language || "pt-PT";
  setLocale(initialLocale);
  updateInternalLinks(normalizeLocale(initialLocale));

  pickerButton?.addEventListener("click", () => {
    const open = picker.classList.toggle("open");
    pickerButton.setAttribute("aria-expanded", String(open));
  });
  menu?.addEventListener("click", (e) => {
    const button = e.target.closest("[data-locale]");
    if (button) {
      setLocale(button.dataset.locale);
      picker.classList.remove("open");
      pickerButton.setAttribute("aria-expanded","false");
      return;
    }
    const link = e.target.closest("[data-locale-link]");
    if (link) {
      const locale = link.getAttribute("data-locale-link");
      if (locale) localStorage.setItem("dailytalk.landing.locale", locale);
    }
  });
  document.addEventListener("click", (e) => {
    if (picker && !picker.contains(e.target)) {
      picker.classList.remove("open");
      pickerButton?.setAttribute("aria-expanded","false");
    }
  });

  navToggle?.addEventListener("click", () => {
    const open = nav.classList.toggle("open");
    navToggle.setAttribute("aria-expanded", String(open));
  });
  nav?.querySelectorAll("a").forEach(a => a.addEventListener("click", () => {
    nav.classList.remove("open");
    navToggle?.setAttribute("aria-expanded","false");
  }));

  // "Testar agora" is always available:
  // hero CTA while it is visible; sticky desktop/mobile CTA as soon as it leaves the viewport.
  if ("IntersectionObserver" in window && heroTest) {
    const observer = new IntersectionObserver(([entry]) => {
      const showSticky = !entry.isIntersecting;
      if (window.matchMedia("(min-width: 621px)").matches) {
        stickyTest?.classList.toggle("is-hidden", !showSticky);
        mobileTest?.classList.add("is-hidden");
      } else {
        mobileTest?.classList.toggle("is-hidden", !showSticky);
        stickyTest?.classList.add("is-hidden");
      }
    }, {threshold: 0.25});
    observer.observe(heroTest);
  }

  window.addEventListener("resize", () => {
    if (heroTest?.getBoundingClientRect().bottom < 0) {
      const mobile = window.matchMedia("(max-width: 620px)").matches;
      stickyTest?.classList.toggle("is-hidden", mobile);
      mobileTest?.classList.toggle("is-hidden", !mobile);
    }
  });

  document.querySelectorAll("[data-locale-link]").forEach(link => {
    link.addEventListener("click", () => {
      const locale = link.getAttribute("data-locale-link");
      if (locale) localStorage.setItem("dailytalk.landing.locale", locale);
    });
  });
})();
