λ(espPartUuid : Text) →
λ(rootfsLuksUuid : Text) →
  { hostname = "viper.local"
  , zoneInfo = "Europe/London"
  , locale = "en_US"
  , keymap = "us"
  , storage = ./storage.dhall espPartUuid rootfsLuksUuid
  , pacman = ./pacman.dhall
  , extraFiles = ./extraFiles.dhall
  }
