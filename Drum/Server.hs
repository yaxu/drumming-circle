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
import Control.Monad (when)
import Control.Monad.Trans (liftIO)
import Data.Unique

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
                      cFH :: Maybe Handle,
                      cConn :: WS.Connection,
                      cId :: Unique
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
  mClients <- newMVar []
  WS.runServer "0.0.0.0" port $ (\pending -> do
    conn <- WS.acceptRequest pending

    putStrLn $  "received new connection"
    (senderThreadId, sender) <- wsSend conn

    sender $ "/welcome"
    
    WS.forkPingThread conn 30
    uniqueId <- liftIO newUnique
    let client = Client {cName = "anonymous",
                         cServerThread = senderThreadId,
                         cSender = sender,
                         cFH = Nothing,
                         cConn = conn,
                         cId = uniqueId
                        }
    clients <- liftIO $ takeMVar mClients
    liftIO $ putMVar mClients $ client:clients
    loop mClients client conn
    )
  putStrLn "done."

loop :: MVar [Client] -> Client -> WS.Connection -> IO ()
loop mClients client conn = do
  msg <- try (WS.receiveData conn)
  -- add to dictionary of connections -> patterns, could use a map for this
  case msg of
    Right s -> do
      putStrLn $ "msg: " ++ T.unpack s
      client' <- act mClients client conn (T.unpack s)
      clients <- takeMVar mClients
      putMVar mClients $ updateClient clients client'
      loop mClients client' conn
    Left WS.ConnectionClosed   -> close mClients client "unexpected loss of connection"
    Left (WS.CloseRequest _ _) -> close mClients client "by request from peer"
    Left (WS.ParseException e) -> close mClients client ("parse exception: " ++ e)

removeClient :: [Client] -> Client -> [Client]
removeClient cs c = filter (\c' -> cId c' /= cId c) cs

updateClient :: [Client] -> Client -> [Client]
updateClient cs c = c:(removeClient cs c)

close :: MVar [Client] -> Client -> String -> IO ()
close mClients client msg = do
  putStrLn ("connection closed: " ++ msg)
  let fh = cFH client
  cs <- takeMVar mClients
  putMVar mClients $ removeClient cs client
  when (isJust fh) $ do
    hClose $ fromJust fh
-- hush = mapM_ ($ Tidal.silence)

-- TODO: proper parsing..
takeNumbers :: String -> (String, String)
takeNumbers xs = (takeWhile f xs, dropWhile (== ' ') $ dropWhile f xs)
  where f x = not . null $ filter (x ==) "0123456789."

commands = [("name", act_name),
            ("change", act_change),
            ("takeSnapshots", act_takeSnapshots),
            ("replay", act_replay)
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

getCommand :: String -> Maybe (MVar [Client] -> Client -> WS.Connection -> IO Client)
getCommand ('/':s) = do f <- lookup command commands
                        param <- stripPrefix command s
                        let param' = dropWhile (== ' ') param
                        return $ f param'
  where command = takeWhile (/= ' ') s
getCommand _ = Nothing

act :: MVar [Client] -> Client -> WS.Connection -> String -> IO Client
act mClients client conn request = (fromMaybe act_no_parse $ getCommand request) mClients client conn

act_no_parse _ client conn = do cSender client $ "/noparse"
                                return client


act_name :: String -> MVar [Client] -> Client -> WS.Connection -> IO (Client)
act_name param _ client conn =
  do putStrLn $ "name: '" ++ param ++ "'"
     cSender client $ "/name ok hello " ++ param
     return $ client {cName = param}

act_change :: String -> MVar [Client] -> Client -> WS.Connection -> IO (Client)
act_change param _ client conn =
  do fh <- getFH (cFH client)
     hPutStrLn fh $ "//"
     hPutStrLn fh param
     hFlush fh
     return (client {cFH = Just fh})
       where getFH (Just fh) = return fh
             getFH Nothing =
               do createDirectoryIfMissing True logDirectory
                  fh <- openFile fn AppendMode
                  hPutStrLn fh $ "// connect"
                  return fh
             fn = "logs" </> (cName client) ++ ".json"
             logDirectory = "logs"


act_takeSnapshots :: String -> MVar [Client] -> Client -> WS.Connection -> IO (Client)
act_takeSnapshots param mClients client conn =
  do putStrLn $ "takeSnapshot [" ++ param ++ "]."
     cs <- readMVar mClients
     mapM_ (\conn -> WS.sendTextData conn (T.pack $ "/takeSnapshot " ++ param)) $ map cConn cs
     return $ client


act_replay :: String -> MVar [Client] -> Client -> WS.Connection -> IO (Client)
act_replay param mClients client conn =
  do putStrLn $ "replay [" ++ param ++ "]."
     cs <- readMVar mClients
     mapM_ (\conn -> WS.sendTextData conn (T.pack $ "/replay " ++ param)) $ map cConn cs
     return $ client

