import Drum.Client
import System.Environment

main = do argv <- getArgs
          replay $ head argv
