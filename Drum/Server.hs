-- Released under terms of GNU Public License version 3
-- (c) Alex McLean 2017

{-# LANGUAGE OverloadedStrings, FlexibleContexts #-}

module Drum.Server where

import Control.Exception (try)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified Network.WebSockets as WS
import Data.List
import Data.Maybe
import Control.Concurrent
import Control.Concurrent.MVar
import System.Directory
import System.FilePath
import System.IO

-- import Data.Ratio
-- import System.Process
-- import Data.Time.Clock.POSIX
-- import Data.Fixed (mod')
-- import Text.JSON
-- import qualified Data.ByteString.Lazy.Char8 as C
-- import Control.Applicative

port = 6010

data Client = Client {cName :: String,
                      cServerThread :: ThreadId,
                      cSender :: String -> IO (),
                      cFH :: Maybe Handle
                     }

wsSend :: WS.Connection -> IO (ThreadId, String -> IO())
wsSend conn =
  do sendQueue <- newEmptyMVar
     threadId <- (forkIO $ sender sendQueue)
     return (threadId, putMVar sendQueue)
  where
    sender :: MVar String -> IO ()
    sender sendQueue = do s <- takeMVar sendQueue
                          WS.sendTextData conn (T.pack s)
                          sender sendQueue

run = do
  putStrLn $ "Drumming circle server, starting on port " ++ show port
  mConnectionId <- newMVar 0
  WS.runServer "0.0.0.0" port $ (\pending -> do
    conn <- WS.acceptRequest pending

    putStrLn $  "received new connection"
    (senderThreadId, sender) <- wsSend conn

    sender $ "/welcome"
    
    WS.forkPingThread conn 30

    let clientState = Client {cName = "anonymous",
                              cServerThread = senderThreadId,
                              cSender = sender,
                              cFH = Nothing
                             }
    loop clientState conn
    )
  putStrLn "done."

loop :: Client -> WS.Connection -> IO ()
loop clientState conn = do
  msg <- try (WS.receiveData conn)
  -- add to dictionary of connections -> patterns, could use a map for this
  case msg of
    Right s -> do
      putStrLn $ "msg: " ++ T.unpack s
      clientState' <- act clientState conn (T.unpack s)
      loop clientState' conn
    Left WS.ConnectionClosed   -> close clientState "unexpected loss of connection"
    Left (WS.CloseRequest _ _) -> close clientState "by request from peer"
    Left (WS.ParseException e) -> close clientState ("parse exception: " ++ e)

close :: Client -> String -> IO ()
close clientState msg = do
  putStrLn ("connection closed: " ++ msg)
-- hush = mapM_ ($ Tidal.silence)

-- TODO: proper parsing..
takeNumbers :: String -> (String, String)
takeNumbers xs = (takeWhile f xs, dropWhile (== ' ') $ dropWhile f xs)
  where f x = not . null $ filter (x ==) "0123456789."

commands = [("name", act_name),
            ("change", act_change)
           {-("play", act_play),
            ("record", act_record),
            ("typecheck", act_typecheck) ,
            ("renderJSON", act_renderJSON) ,
            ("renderSVG", act_renderSVG),
            ("panic", act_panic),
            ("wantbang", act_wantbang),
            ("shutdown", act_shutdown),
            ("nudge", act_nudge),
            ("cps_delta ", act_cps_delta),
            ("cps", act_cps),
            ("bang", act_bang True),
            ("nobang", act_bang False)-}
           ]

getCommand :: String -> Maybe (Client -> WS.Connection -> IO Client)
getCommand ('/':s) = do f <- lookup command commands
                        param <- stripPrefix command s
                        let param' = dropWhile (== ' ') param
                        return $ f param'
  where command = takeWhile (/= ' ') s
getCommand _ = Nothing

act :: Client -> WS.Connection -> String -> IO Client
act clientState conn request = (fromMaybe act_no_parse $ getCommand request) clientState conn

act_no_parse clientState conn = do cSender clientState $ "/noparse"
                                   return clientState


act_name :: String -> Client -> WS.Connection -> IO (Client)
act_name param clientState conn =
  do putStrLn $ "name: '" ++ param ++ "'"
     cSender clientState $ "/name ok hello " ++ param
     return $ clientState {cName = param}

act_change :: String -> Client -> WS.Connection -> IO (Client)
act_change param clientState conn =
  do fh <- getFH (cFH clientState)
     hPutStrLn fh $ "//"
     hPutStrLn fh param
     hFlush fh
     return (clientState {cFH = Just fh})
       where getFH (Just fh) = return fh
             getFH Nothing =
               do createDirectoryIfMissing True logDirectory
                  openFile fn AppendMode
             fn = "logs" </> (cName clientState) ++ ".json"
             logDirectory = "logs"
