{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import RIO
import RIO.FilePath ((</>))
import RIO.Process
import RIO.Text (pack)

import Options.Generic
import UnliftIO.Environment (getProgName)

import Checks
import Chroot
import Config
import Install

data CmdOpts
    = BuildRootfs { confPath :: FilePath }
    | ConfigureRootfsChroot { binConfPath :: FilePath }
    | CopyDiskImages { confPath :: FilePath }
    deriving (Generic)

instance ParseRecord CmdOpts where
    parseRecord = parseRecordWithModifiers $ lispCaseModifiers {shortNameModifier = firstLetter}

data App = App
    { saLogFunc :: !LogFunc
    , saProcessContext :: !ProcessContext
    }

instance HasLogFunc App where
    logFuncL = lens saLogFunc (\x y -> x {saLogFunc = y})

instance HasProcessContext App where
    processContextL = lens saProcessContext (\x y -> x {saProcessContext = y})

main :: IO ()
main = do
    cmd <- pack <$> getProgName >>= getRecord
    let run =
            case cmd
                -- TODO: fetch /etc + /home BTRFS subvols
                  of
                BuildRootfs confPath -> do
                    doPreInstallChecks
                    sysConf <- loadSystemConfig $ confPath </> "system.dhall"
                    buildRootfs sysConf
                ConfigureRootfsChroot binConfPath -> do
                    sysConf <- loadBinSystemConfig binConfPath
                    configureRootfs sysConf
                CopyDiskImages confPath -> do
                    doPreInstallChecks
                    sysConf <- loadSystemConfig $ confPath </> "system.dhall"
                    doPreCopyChecks sysConf
                    copyDiskRootfsImage sysConf
                    -- XXX installBootloader sysConf
    runApp $ do
        catch run (\(ex :: SomeException) -> logError (displayShow ex) >> liftIO exitFailure)
        logInfo "Done"

runApp :: MonadIO m => RIO App a -> m a
runApp m =
    liftIO $ do
        lo <- logOptionsHandle stderr True
        pc <- mkDefaultProcessContext
        withLogFunc lo $ \lf ->
            let simpleApp = App {saLogFunc = lf, saProcessContext = pc}
             in runRIO simpleApp m
