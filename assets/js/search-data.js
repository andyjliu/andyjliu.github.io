// get the ninja-keys element
const ninja = document.querySelector('ninja-keys');

// add the home and posts menu items
ninja.data = [{
    id: "nav-about",
    title: "about",
    section: "Navigation",
    handler: () => {
      window.location.href = "/";
    },
  },{id: "nav-blog",
          title: "blog",
          description: "",
          section: "Navigation",
          handler: () => {
            window.location.href = "/blog/";
          },
        },{id: "nav-publications",
          title: "publications",
          description: "",
          section: "Navigation",
          handler: () => {
            window.location.href = "/publications/";
          },
        },{id: "nav-cv",
          title: "cv",
          description: "",
          section: "Navigation",
          handler: () => {
            window.location.href = "/cv/";
          },
        },{id: "post-when-llms-can-write-fiction-how-will-we-know",
      
        title: "when llms can write fiction, how will we know?",
      
      description: "on evals of subjective tasks",
      section: "Posts",
      handler: () => {
        
          window.location.href = "/blog/2025/subjective-evals/";
        
      },
    },{id: "books-the-godfather",
          title: 'The Godfather',
          description: "",
          section: "Books",handler: () => {
              window.location.href = "/books/the_godfather/";
            },},{id: "news-i-started-a-phd-at-cmu-s-language-technologies-institute",
          title: 'I started a PhD at CMU’s Language Technologies Institute.',
          description: "",
          section: "News",},{id: "news-i-presented-my-first-phd-paper-evaluating-large-language-model-biases-in-persona-steered-generation-at-acl-2024-in-bangkok",
          title: 'I presented my first PhD paper, Evaluating Large Language Model Biases in Persona-Steered...',
          description: "",
          section: "News",},{id: "news-our-paper-on-dynamic-coalition-structure-detection-in-natural-language-based-interactions-was-accepted-to-aamas-2025-see-you-in-detroit",
          title: 'Our paper on Dynamic Coalition Structure Detection in Natural-Language-based Interactions was accepted to...',
          description: "",
          section: "News",},{id: "news-i-was-awarded-a-2025-nsf-graduate-research-fellowship",
          title: 'I was awarded a 2025 NSF Graduate Research Fellowship.',
          description: "",
          section: "News",},{id: "news-i-ve-joined-meta-fair-in-seattle-as-a-research-intern-working-with-ruta-desai-on-training-collaborative-agents",
          title: 'I’ve joined Meta FAIR in Seattle as a research intern, working with Ruta...',
          description: "",
          section: "News",},{
        id: 'social-email',
        title: 'email',
        section: 'Socials',
        handler: () => {
          window.open("mailto:%61%6E%64%79%6C%69%75@%63%73.%63%6D%75.%65%64%75", "_blank");
        },
      },{
        id: 'social-github',
        title: 'GitHub',
        section: 'Socials',
        handler: () => {
          window.open("https://github.com/andyjliu", "_blank");
        },
      },{
        id: 'social-scholar',
        title: 'Google Scholar',
        section: 'Socials',
        handler: () => {
          window.open("https://scholar.google.com/citations?user=FtdDAMoAAAAJ&hl=en", "_blank");
        },
      },{
        id: 'social-x',
        title: 'X',
        section: 'Socials',
        handler: () => {
          window.open("https://twitter.com/uilydna", "_blank");
        },
      },{
      id: 'light-theme',
      title: 'Change theme to light',
      description: 'Change the theme of the site to Light',
      section: 'Theme',
      handler: () => {
        setThemeSetting("light");
      },
    },
    {
      id: 'dark-theme',
      title: 'Change theme to dark',
      description: 'Change the theme of the site to Dark',
      section: 'Theme',
      handler: () => {
        setThemeSetting("dark");
      },
    },
    {
      id: 'system-theme',
      title: 'Use system default theme',
      description: 'Change the theme of the site to System Default',
      section: 'Theme',
      handler: () => {
        setThemeSetting("system");
      },
    },];
