{-# LANGUAGE OverloadedStrings #-}

import Control.Applicative
import Control.Monad
import qualified Data.HashMap.Strict as HM
import Data.Function(on)
import Data.List(sortBy)
import Data.Maybe
import Data.Monoid
import Data.Yaml
import Data.OrgMode.Parse.Attoparsec.Document
import Data.OrgMode.Parse.Attoparsec.Time
import Data.OrgMode.Parse.Attoparsec.Headings
import Data.OrgMode.Parse.Types
import Data.Attoparsec.Text
import Data.Thyme.Calendar (YearMonthDay)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified System.Console.ANSI as C
import System.Environment
import Text.Printf
import Text.Read (readMaybe)

type Timespan      = (Timestamp, Duration)

durationOfTimespan :: Timespan -> Double
durationOfTimespan (_,(h,m)) = fromIntegral $ 60*h+m

isBefore :: Timestamp -> Timestamp -> Bool
isBefore a b = un a <= un b
  where
    un :: Timestamp -> YearMonthDay
    un ts = let YMD' x = yearMonthDay $ tsTime ts in x

data Project = Project
  { projHeading :: Heading
  , allocation :: Maybe (Double, Timestamp)
  , timeUsed :: Double
  , timeDeserve :: Double
  , doThis :: Bool
  }


type ProjPriority = (Double,Double)
projPriority :: Project -> ProjPriority
projPriority p = (timeDeserve p - timeUsed p, fromMaybe 0 (fst <$> allocation p))

projListingOrder :: Project -> (Bool,Double,Int)
projListingOrder p = (not $ isJust $ allocation p ,
                      negate $ fst $ projPriority p,
                      negate $ countHeadingTime $ projHeading p)


addProject :: Project -> Project -> Project
addProject a b = Project
                 {projHeading = ((projHeading a){title="Total"}),
                  allocation = (addA (allocation a) (allocation b)),
                  timeUsed = (timeUsed a + timeUsed b),
                  timeDeserve = (timeDeserve a + timeDeserve b),
                  doThis = False
                  }
  where
    addA (Just (wa,ta)) (Just (wb,tb)) = Just (wa+wb, ta) -- smaller of?
    addA a b = a <|> b


thow :: Show a => a -> T.Text
thow = T.pack . show

main :: IO ()
main = getArgs >>= mapM_ process

process :: FilePath -> IO ()
process fn = do
  input <- T.readFile fn
  let r = parse (parseDocument []) input
  case r of
    Done remain doc -> do
                       use doc
                       putStrLn "PARSER DISCONTINUED!"
                       T.putStrLn $ T.take 100 remain
    Partial k -> case k "" of
      Done _ doc -> use doc
      x -> print x
    x -> print x

use :: Document -> IO ()
use doc = do
  encodeFile "debug.yaml" doc
  T.writeFile "debug.txt" $ thow doc

  let projs = concat $ map (toProjects 0) $ documentHeadings doc
      spans :: [Timespan]
      spans = concat $ map spansOfProj projs
      projs1 = map fillTimeUsed projs
      projs2 = foldr redistribute projs1 spans

      hiscore = maximum $ map projPriority projs2
      projsRet = markDoThis hiscore projs2

  printf "Total Deserv   Used Assign WGT Task\n"
  mapM_ pprProj $ sortBy (compare `on` projListingOrder) projsRet ++ [foldr1 addProject projsRet  ]

pprProj :: Project -> IO ()
pprProj proj = do
  let h = projHeading proj
      debt = (timeDeserve proj) -(timeUsed proj)

      color
        | doThis proj = C.Yellow
        | debt < -1 = C.Blue
        | debt >  1 = C.Green
        | otherwise = C.White
      cinten
        | doThis proj = C.BoldIntensity
        | otherwise = C.NormalIntensity
      inten
        | doThis proj = C.Vivid
        | otherwise = C.Dull
  C.setSGR [C.SetColor C.Foreground inten  color, C.SetConsoleIntensity cinten]
  putStrLn $ printf "%5d %6.0f %6.0f %6s %3.0f %s" (countHeadingTime h)
    (timeDeserve proj)
    (timeUsed proj)
    (hm $ timeDeserve proj - timeUsed proj)
    (fromMaybe 0 (fst <$> allocation proj))  (T.unpack $ title h)

  where
    hm :: Double -> String
    hm x
      | abs x < 1e-14 = "0"
      | x < 0 = "-" ++ hm (negate x)
      | otherwise = let
          (h,m) = divMod (round x) (60 ::Int)
          in printf "%d:%02d" h m

fillTimeUsed :: Project -> Project
fillTimeUsed proj = foldr earnUsed proj spans
  where spans = spansOfProj proj


redistribute :: Timespan -> [Project] -> [Project]
redistribute ts projs =
  if sumShare == 0 then projs
  else map (earnDeserve ts (durationOfTimespan ts / sumShare)) projs
  where
    sumShare = sum $ map (claimShare ts) projs

claimShare :: Timespan -> Project -> Double
claimShare (ts1,_) proj = case allocation proj of
  Nothing -> 0
  Just (w, ts2) -> if ts2 `isBefore` ts1 then w else 0

earnDeserve :: Timespan -> Double -> Project -> Project
earnDeserve (ts1,_) share proj = case allocation proj of
  Nothing -> proj
  Just (w, ts2) -> if ts2 `isBefore` ts1 then proj{timeDeserve = timeDeserve proj + share*w } else proj

earnUsed :: Timespan -> Project -> Project
earnUsed t@(ts1,_) proj = case allocation proj of
  Nothing -> proj
  Just (w, ts2) -> if ts2 `isBefore` ts1 then proj{timeUsed = timeUsed proj + durationOfTimespan t} else proj



toProjects :: Int -> Heading -> [Project]
toProjects level h = meAsProject ++ concat (map (toProjects (level+1)) (subHeadings h))
  where
    Plns plmap = sectionPlannings $ section h

    alloc :: Maybe (Double, Timestamp)
    alloc = do
      sts <- HM.lookup SCHEDULED plmap
      guard $ HM.lookup CLOSED plmap == Nothing
      (w:_) <- return $ catMaybes $ map parseWeight $ T.lines $ sectionParagraph $ section h
      return (w,sts)

    meAsProject :: [Project]
    meAsProject
     | -- level <= 0   || -- I'll suspend the level 0 track for the moment.
       isJust alloc = [Project{projHeading = h, allocation = alloc, timeUsed = 0, timeDeserve = 0, doThis = False}]
     | otherwise  = []


parseWeight :: T.Text -> Maybe Double
parseWeight str = do
  [k,v] <- return $ T.words str
  guard $ k == "WEIGHT:"
  readMaybe $ T.unpack v


countHeadingTime :: Heading -> Int
countHeadingTime h = t + t2
  where
      t = sum $ map durationMin $ (ts1 ++ ts2)
      ts1 = sectionClocks $ section h
      ts2 = map p1 $
            T.lines $ sectionParagraph $ section h
      p1 = fromMaybe (Nothing, Nothing) . maybeResult . parse parseClock . (<> "\n")

      t2 = sum $ map countHeadingTime $ subHeadings h

findSpans :: Heading -> [Timespan]
findSpans h = t ++ t2
  where
      t =  concat $ map toTimespan $ (ts1 ++ ts2)
      ts1 = sectionClocks $ section h
      ts2 = map p1 $
            T.lines $ sectionParagraph $ section h
      p1 = fromMaybe (Nothing, Nothing) . maybeResult . parse parseClock . (<> "\n")

      t2 = concat $ map findSpans $ subHeadings h

      toTimespan (Just a, Just b) = [(a,b)]
      toTimespan _ = []

spansOfProj :: Project -> [Timespan]
spansOfProj proj = case allocation proj of
  Nothing -> []
  Just (_,tsp)  -> filter (\(tss,_) -> tsp `isBefore` tss) $ findSpans $ projHeading proj

durationMin :: (Maybe Timestamp, Maybe Duration) -> Int
durationMin (_, Nothing) = 0
durationMin (_, Just (h,m)) = h*60+m

markDoThis :: ProjPriority -> [Project] -> [Project]
markDoThis prio [] = error "hiscore not found"
markDoThis prio (x:xs)
  | projPriority x >= prio = x{doThis = True} : xs
  | otherwise              = x:markDoThis prio xs
