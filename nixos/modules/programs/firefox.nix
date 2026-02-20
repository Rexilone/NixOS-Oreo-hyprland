{
  programs.firefox = {
    enable = true;
    languagePacks = [ "ru" "en-US" ];
    
    # 1. Глобальные политики (вырезаем мусор и телеметрию)
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFeedbackCommands = true;
      DisplayBookmarksBar = "never"; # Скрывает панель закладок
      
      # Чистая домашняя страница (убираем лого, топ сайтов и т.д.)
      FirefoxHome = {
        Search = true;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        SponsoredPocket = false;
        Snippets = false;
      };

      # Заставляем Google быть главным поисковиком
      SearchEngines = {
        Default = "Google";
        PreventInstalls = false;
      };
    };

    # 2. Тонкие настройки (производительность и UI)
    preferences = {
      # Твои старые настройки ускорения
      "media.ffmpeg.vaapi.enabled" = true;
      "media.rdd-ffvpx.enabled" = false;
      "gfx.webrender.all" = true;
      "layers.acceleration.force-enabled" = true;
      "widget.dmabuf.force-enabled" = true;
      "media.ffvpx.enabled" = false;

      # ДОПОЛНИТЕЛЬНО ДЛЯ МИНИМАЛИЗМА:
      "browser.startup.page" = 1; # Открывать домашнюю страницу
      "browser.newtabpage.enabled" = true;
      "browser.aboutConfig.showWarning" = false; # Убрать предупреждение в about:config
      "browser.formfill.enable" = false; # Не запоминать формы (чуть быстрее)
      "datareporting.healthreport.uploadEnabled" = false; # Еще раз вырубаем отчеты
      
      # Ограничение процессов для 4 ГБ ОЗУ (критично для ноута!)
      "dom.ipc.processCount" = 2; 

      # Убираем "рекомендации" в адресной строке (чтобы не лагало при вводе)
      "browser.urlbar.suggest.quicksuggest.sponsored" = false;
      "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
      "browser.urlbar.suggest.topsites" = false;

      # Принудительная темная тема на уровне системы
      "ui.systemUsesDarkTheme" = 1;
      "browser.theme.contenttheme" = 2; # Темная тема для контента (about:newtab и т.д.)
      
      # Установка цвета фона #151515 для новых вкладок и пустых страниц
      "browser.display.background_color" = "#151515";
      "browser.newtabpage.activity-stream.customization.system-ui-theme" = true;
      
      # Чтобы Firefox не "ослеплял" белым цветом при открытии новой вкладки
      "browser.display.use_system_colors" = false;
      "browser.anchor_color" = "#0000ee"; # стандартный цвет ссылок
      
      # Цвета для "пустых" страниц (about:blank и начало загрузки)
      "msg.autoscroll.background_color" = "#151515";
    };
  };
}
