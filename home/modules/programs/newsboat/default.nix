{ config, pkgs, ... }:

let
  scripts = {
    newsboat-bookmark = pkgs.writeShellScriptBin "newsboat-bookmark"
      (builtins.readFile ./bookmark.sh);
    newsboat-cli-browser = pkgs.writeShellScriptBin "newsboat-cli-browser"
      (builtins.readFile ./cli-browser.sh);
  };
in {
  imports = [ ../../colors.nix ];

  home.packages = with pkgs; [
    scripts.newsboat-bookmark
    scripts.newsboat-cli-browser
  ];

  programs.newsboat = {
    enable = true;
    urls = [
      # wath
      { url = "--watch--"; }
      { url = "https://hnrss.org/replies?id=_andrei_"; }
      {
        url =
          "https://raw.githubusercontent.com/gitkeep/bookmarks/master/feed.xml";
      }

      # news
      { url = "---news---"; }
      { url = "https://hnrss.org/frontpage"; }
      { url = "https://hnrss.org/best"; }
      { url = "https://hnrss.org/newest?points=20"; }
      { url = "https://lobste.rs/rss"; }
      { url = "https://restofworld.org/feed/latest"; }
      { url = "https://www.theatlantic.com/feed/all"; }
      { url = "https://www.theguardian.com/business/economics/rss"; }
      { url = "http://feeds.nature.com/nature/rss/current"; }
      { url = "https://www.sciencedaily.com/rss/top.xml"; }
      { url = "https://phys.org/rss-feed/breaking/"; }
      { url = "https://nautil.us/feed/"; }
      { url = "https://feeds.npr.org/1001/rss.xml"; }
      { url = "https://www.theverge.com/rss/index.xml"; }
      { url = "https://www.protocol.com/feeds/feed.rss"; }
      { url = "https://time.com/feed/"; }
      { url = "https://feeds.arstechnica.com/arstechnica/index"; }
      { url = "https://rss.packetstormsecurity.com/files/"; }
      { url = "https://www.producthunt.com/feed?category=undefined"; }
      { url = "https://cdn.hackernoon.com/feed"; }
      { url = "https://thenextweb.com/feed"; }
      { url = "https://feeds.feedburner.com/brainpickings/rss"; }
      { url = "https://www.openculture.com/feed"; }
      {
        url = "https://aeon.co/feed.rss";
      }

      # reddit
      { url = "---reddit---"; }
      { url = "https://inline-reddit.com/feed/?subreddit=worldnews/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=science/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=NixOS/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=neovim/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=vim/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=emacs/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=commandline/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=compsci/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=coding/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=linux/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=programming/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=frontend/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=javascript/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=opensource/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=selfhosted/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=golang/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=rust/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=node/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=reactjs/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=vuejs/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=html5/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=css/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=hacking/best"; }
      {
        url =
          "https://inline-reddit.com/feed/?subreddit=coolgithubprojects/best";
      }
      { url = "https://inline-reddit.com/feed/?subreddit=dotfiles/best"; }
      {
        url =
          "https://inline-reddit.com/feed/?subreddit=softwaredevelopment/best";
      }
      { url = "https://inline-reddit.com/feed/?subreddit=tinycode/best"; }
      { url = "https://inline-reddit.com/feed/?subreddit=unixporn/best"; }
      {
        url = "https://inline-reddit.com/feed/?subreddit=listentothis/best";
      }

      # youtube
      { url = "---youtube---"; }
      {
        url =
          "https://www.youtube.com/feeds/videos.xml?channel_id=UClcE-kVhqyiHCcjYwcpfj9w";
      } # LifeOverflow
      {
        url =
          "https://www.youtube.com/feeds/videos.xml?channel_id=UC8ENHE5xdFSwx71u3fDH5Xw";
      } # ThePrimeagen
      {
        url =
          "https://www.youtube.com/feeds/videos.xml?channel_id=UCUyeluBRhGPCW4rPe_UvBZQ";
      } # ThePrimeTimeagen
      {
        url =
          "https://www.youtube.com/feeds/videos.xml?channel_id=UCXPHFM88IlFn68OmLwtPmZA";
      } # Greg Hurrell

      # software
      { url = "---software---"; }
      {
        url = "http://blog.chromium.org/feeds/posts/default";
      }

      # podcasts
      { url = "---podcasts---"; }
      {
        url = "https://clearerthinkingpodcast.com/rss.xml";
      }

      # blogs: favourites
      { url = "---blogs::favourites---"; }
      { url = "https://ciechanow.ski/atom.xml"; }
      { url = "https://writings.stephenwolfram.com/feed/"; }
      { url = "https://beepb00p.xyz/rss.xml"; }
      { url = "https://sive.rs/en.atom"; }
      { url = "https://ralphammer.com/feed/"; }
      { url = "https://alain.xyz/rss"; }
      { url = "https://www.lucacambiaghi.com/feed.xml"; }
      {
        url = "https://blog.owulveryck.info/index.xml";
      }

      # blogs: dev
      { url = "---blogs::dev---"; }
      { url = "https://github.com/readme.rss"; }
      { url = "https://rachelbythebay.com/w/atom.xml"; }
      { url = "https://barre.sh/atom.xml"; }
      { url = "https://dataswamp.org/~solene/rss.xml"; }
      { url = "https://web.dev/feed.xml"; }
      { url = "https://css-irl.info/rss.xml"; }
      { url = "https://www.bram.us/feed/"; }
      { url = "https://www.miriamsuzanne.com/feed.xml"; }
      { url = "https://tympanus.net/codrops/feed/"; }
      { url = "https://css-tricks.com/feed/"; }
      { url = "https://thenewcode.com/feed.php"; }
      { url = "https://sethmlarson.dev/feed"; }
      { url = "https://thoughtspile.github.io/atom.xml"; }
      { url = "https://matt-rickard.com/rss/"; }
      { url = "https://www.huy.rocks/rss.xml"; }
      { url = "https://www.hacklewayne.com/rss/index.xml"; }
      { url = "https://calendar.perfplanet.com/feed/"; }
      {
        url = "https://eugeneyan.com/rss/";
      }

      # blogs: security
      { url = "---blogs::security---"; }
      { url = "https://portswigger.net/research/rss"; }
      { url = "https://0xcc.re/feed.xml"; }
      {
        url = "https://www.reversemode.com/feeds/posts/default?alt=rss";
      }

      # blogs: other
      { url = "---blogs::other---"; }
      {
        title = "Jakob Greenfeld";
        url = "https://jakobgreenfeld.com/feed";
      }

      # directories
      { url = "---Directories---"; }
      { url = "http://opensource.com/feed"; }
      { url = "https://opensourcemusings.com/feed"; }
      {
        url = "https://www.linuxlinks.com/feed/";
      }

      # other
      { url = "---Other---"; }
      { url = "https://www.paritybit.ca/feed.xml"; }
      { url = "https://evantravers.com/feed.xml"; }
      { url = "https://christine.website/blog.rss"; }
      { url = "https://xkcd.com/atom.xml"; }
      { url = "http://blog.computationalcomplexity.org/feeds/posts/default"; }
      { url = "http://blog.humblebundle.com/rss"; }
      { url = "http://blog.makezine.com/feed/"; }
      { url = "http://blog.ploeh.dk/rss.xml"; }
      { url = "http://blog.pnkfx.org/atom.xml"; }
      { url = "http://blog.trailofbits.com/feed/"; }
      { url = "http://chrisgammell.com/feed/"; }
      { url = "http://codeascraft.etsy.com/feed/"; }
      { url = "http://corgibytes.com/feed.xml"; }
      { url = "http://cybergibbons.com/feed/"; }
      { url = "http://events.ccc.de/feed/"; }
      { url = "http://feedpress.me/inessential"; }
      { url = "http://fulmicoton.com/atom.xml"; }
      { url = "http://hackaday.com/feed/"; }
      { url = "http://jvns.ca/atom.xml"; }
      { url = "http://maryrosecook.com/blog/feed"; }
      { url = "http://nakedsecurity.sophos.com/feed/"; }
      { url = "http://neverworkintheory.org/feed.xml"; }
      { url = "http://nitschinger.at//index.xml"; }
      { url = "http://serialized.net/rss.xml"; }
      { url = "http://this-week-in-rust.org/atom.xml"; }
      { url = "http://www.2600.com/rss.xml"; }
      { url = "http://www.elidedbranches.com/feeds/posts/default"; }
      { url = "http://www.goldsborough.me/feed.xml"; }
      { url = "http://www.malwaretech.com/feeds/posts/default"; }
      { url = "http://www.mdswanson.com/atom.xml"; }
      { url = "http://www.questionablecontent.net/QCRSS.xml"; }
      { url = "https://ar.al/index.xml"; }
      { url = "https://laurakalbag.com/posts/index.xml"; }
      { url = "https://begriffs.com/atom.xml"; }
      { url = "https://blog.christophersmart.com/feed/"; }
      { url = "https://blog.cyplo.dev/index.xml"; }
      { url = "https://blog.makersacademy.com/feed"; }
      { url = "https://blog.rustfest.eu/feed.xml"; }
      { url = "https://blog.torproject.org/blog/feed"; }
      { url = "https://drewdevault.com/blog/index.xml"; }
      { url = "https://gergely.imreh.net/blog/feed/"; }
      { url = "https://grahamc.com/feed/"; }
      { url = "https://ideatrash.net/feed"; }
      { url = "https://kevq.uk/feed.xml"; }
      { url = "https://krebsonsecurity.com/feed/"; }
      { url = "https://matklad.github.io/feed.xml"; }
      { url = "https://nathanleclaire.com/index.xml"; }
      { url = "https://nora.codes/index.xml"; }
      { url = "https://pointersgonewild.com/feed/"; }
      { url = "https://robertheaton.com/feed"; }
      { url = "https://rusingh.com/feed.xml"; }
      { url = "https://rust-embedded.github.io/blog/rss.xml"; }
      { url = "https://ruudvanasseldonk.com/feed.xml"; }
      { url = "https://sensepost.com/rss.xml"; }
      { url = "https://simplysecure.org/feed.xml"; }
      { url = "https://sourcehut.org/blog/index.xml"; }
      { url = "https://spideroak.com/blog/feed"; }
      { url = "https://thesquareplanet.com/feed.xml"; }
      { url = "https://weekly.nixos.org/feeds/all.rss.xml"; }
      { url = "https://www.destroyallsoftware.com/blog/index.xml"; }
      { url = "https://www.destroyallsoftware.com/screencasts/feed"; }
      { url = "https://www.evilsocket.net/atom.xml"; }
      { url = "https://www.insinuator.net/feed/"; }
      { url = "https://www.schneier.com/feed/atom/"; }
      { url = "https://www.unixsheikh.com/feed.rss"; }
    ];
    extraConfig = with config; ''
      auto-reload yes
      confirm-exit no
      download-full-page yes
      download-retries 4
      download-timeout 10
      feed-sort-order none
      goto-next-feed no
      ignore-mode "display"
      podcast-auto-enqueue yes
      prepopulate-query-feeds yes
      reload-threads 20
      reload-time 10
      scrolloff 5
      show-read-articles yes
      show-read-feeds yes
      text-width 80

      browser "setsid -f xdg-open '%u' &> /dev/null"
      html-renderer "newsboat-cli-browser"

      cache-file ~/brain/storage/newsboat/cache.db
      error-log ~/brain/storage/newsboat/error.log
      save-path ~/brain/storage/newsboat/saved

      datetime-format "%Y-%m-%d"
      feedlist-format "%6i %t %u"
      articlelist-format "%D %t"

      highlight feedlist "HN " color9 default bold
      highlight feedlist "Youtube " color1 default bold
      highlight feedlist "---.*---" color5 default

      highlight articlelist "Blog:" color5 default
      highlight articlelist "Podcast:" color5 default
      highlight articlelist "Youtube:" color5 default
      highlight articlelist "[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}" cyan default

      highlight article "^Feed:.*" color6
      highlight article "^Title:.*" color4 default bold
      highlight article "^Author:.*" color1
      highlight article "^Date:.*" color3
      highlight article "^Link:.*" color5
      highlight article "^Flags:.*" color9
      highlight article "https?://[^ ]+" color5 default
      highlight article ":.*\\(link\\)$" color5 default
      highlight article "\\[[0-9][0-9]*\\]" color7 default bold
      highlight article "\\[image [0-9][0-9]*\\]" color7 default bold
      highlight article "\\[embedded flash: [0-9][0-9]*\\]" color7   default bold

      color background color7 default
      color listnormal color8 default
      color listnormal_unread color3 default bold
      color listfocus color7 color0 bold
      color listfocus_unread color7 color0 bold
      color info color7 color0
      color article white default

      bind-key SPACE macro-prefix
      macro m set browser "setsid -f mpv --really-quiet --no-terminal" ; open-in-browser ; set browser "setsid xdg-open '%u' &> /dev/null"

      macro SPACE set browser "newsboat-cli-browser %u" ; open-in-browser ; set browser "setsid xdg-open '%u' &> /dev/null"
      bind-key o open-in-browser-noninteractively

      bind-key j down
      bind-key k up
      bind-key J next-feed articlelist
      bind-key K prev-feed articlelist
      bind-key u pageup
      bind-key s pageup
      bind-key d pagedown
      bind-key ^D pagedown
      bind-key ^U pageup
      bind-key i sort
      bind-key I rev-sort
      bind-key g home
      bind-key G end
      bind-key n next-unread
      bind-key N prev-unread
      bind-key a toggle-article-read
      bind-key U show-urls
      bind-key . toggle-show-read-feeds

      bind-key q quit
      bind-key BACKSPACE quit
      bind-key S save

      # bookmarks
      bind-key b bookmark
      bookmark-cmd newsboat-bookmark
      bookmark-interactive no
      bookmark-autopilot yes
    '';
  };

  programs.fish.shellAliases = { news = "tmux -2 new -As news newsboat"; };
}
