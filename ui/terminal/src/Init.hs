{-# LANGUAGE OverloadedStrings #-}
module Init
  ( Flags(..)
  , run
  )
  where


import Prelude hiding (init)
import Control.Monad.Trans (liftIO)
import qualified Data.ByteString.Lazy as LBS
import Data.Monoid ((<>))
import qualified Network.HTTP.Client as Client

import qualified Elm.Compiler.Version as Compiler
import qualified Elm.Package as Pkg
import qualified Reporting.Doc as D
import qualified Reporting.Exit as Exit
import qualified Reporting.Exit.Init as E
import qualified Reporting.Task as Task
import qualified Reporting.Task.Http as Http
import qualified Reporting.Progress.Terminal as Terminal



-- RUN


data Flags =
  Flags
    { _embed :: Bool
    , _fullscreen :: Bool
    }


run :: () -> Flags -> IO ()
run () flags =
  do  reporter <- Terminal.create
      Task.run reporter $
        do  approved <- Task.getApproval question
            if approved
              then init flags
              else liftIO $ putStrLn "TODO"


question :: D.Doc
question =
  D.stack
    [ "Hello! Elm projects are pretty simple. They include:"
    , D.indent 2 $ D.vcat $
        [ "1. " <> D.green "elm.json" <> D.black " ------------ describes your dependencies"
        , "2. " <> D.green "src/Main.elm" <> D.black " ------ a small Elm program to expand"
        ]
    , customReflow
        "Now you may be wondering, what will be in these files? How do I see\
        \ it in the browser? How will my code grow? Do I need more\
        \ directories? What about tests? Etc. Check out"
        (D.dullyellow (D.fromString (D.makeLink "init")))
        "for all the answers!"
    , "So, would you like me to create these two files now? [Y/n]: "
    ]


customReflow :: String -> D.Doc -> String -> D.Doc
customReflow before doc after =
  D.fillSep $
    map D.fromString (words before) ++ [doc] ++ map D.fromString (words after)



-- INIT


init :: Flags -> Task.Task ()
init flags =
  case flags of
    Flags False False -> download "sandbox"
    Flags True  False -> download "embed"
    Flags False True  -> download "fullscreen"
    Flags _     _     -> Task.throw $ Exit.Init E.ClashingFlags


download :: String -> Task.Task ()
download projectType =
  do  fetch (projectType ++ "/elm.json")
      fetch (projectType ++ "/src/Main.elm")


fetch :: FilePath -> Task.Task ()
fetch path =
  Http.run $
    Http.anything
    ("https://experiment.elm-lang.org/" ++ vsn ++ "/init/" ++ path)
    (\request manager ->
        do  response <- Client.httpLbs request manager
            Right <$> LBS.writeFile path (Client.responseBody response)
    )


vsn :: String
vsn =
  Pkg.versionToString Compiler.version
