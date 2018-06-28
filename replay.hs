import Drum.Client
import System.Environment

main = do argv <- getArgs
          replay (argv !! 1) (argv !! 2)
