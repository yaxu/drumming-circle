import Drum.Client
import System.Environment

main = do argv <- getArgs
          replay (argv !! 0) (argv !! 1)
