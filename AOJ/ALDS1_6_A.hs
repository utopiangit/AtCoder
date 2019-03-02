{-# LANGUAGE BangPatterns #-}
import Control.Monad
import Data.Maybe
import Debug.Trace
import Data.List
import qualified Data.Map.Strict as Map
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Set as Set
import qualified Data.IntSet as IntSet
import Data.Functor
-- import Data.Array
import Data.Array.Unboxed

import Control.Monad.ST
import Data.Array.ST
import qualified Data.Vector as V
import qualified Data.Vector.Unboxed as VU
-- import qualified Data.Vector.Unboxed.Mutable as VM
import qualified Data.Vector.Mutable as VM

import Data.Array.IO
import Data.Array.ST

import qualified Data.ByteString.Char8 as B
import Data.Maybe (fromJust)
readInt = fst . fromJust . B.readInt
readInts = map (fst . fromJust . B.readInt) . B.words <$> B.getLine :: IO [Int]
read2dInts = map (map (fst . fromJust . B.readInt) . B.words) . B.lines <$> B.getContents

main :: IO ()
main = do
  n <- readLn :: IO Int
  as <- readInts
  putStrLn . unwords . map show $ solve as
  -- countingSort''' (0, 10000) as

solve = countingSort (0, 10000)

countingSort :: (Int, Int) -> [Int] -> [Int]
countingSort (s,e) as = concatMap (\(i, n) -> replicate n i) $ IntMap.assocs c
  where
    c = foldr f IntMap.empty as
    f :: Int -> IntMap.IntMap Int -> IntMap.IntMap Int
    f !k dic = IntMap.insertWith (+) k 1 dic


countingSort'' :: (Int, Int) -> [Int] -> [Int]
countingSort'' (s,e) as = join $ foldr g [] [s..e]
  where
    g :: Int -> [[Int]]-> [[Int]]
    g !i acc = (replicate (carr ! i) i):acc

    carr :: UArray Int Int
    carr = runSTUArray $ do
      arr <- newArray (s,e) 0
      forM_ as (\a -> do
        val <- readArray arr a
        writeArray arr a (val + 1) 
        )
      return arr

-- Fastest implementation
countingSort''' :: (Int, Int) -> [Int] -> IO ()
countingSort''' (s,e) as = do
      arr <- newArray (s,e) 0 :: IO (IOUArray Int Int)
      forM_ as (\a -> do
        val <- readArray arr a
        writeArray arr a (val + 1) 
        )
      ass <- getAssocs arr
      putStrLn . unwords . map show $ concatMap (\(i, n) -> replicate n i) ass
    

          

countingSort' :: (Int, Int) -> [Int] -> [Int]
countingSort' (s,e) as = join $ foldr g [] [0..(e-s)] --V.create c
  where
    g :: Int -> [[Int]]-> [[Int]]
    g i acc = (replicate (c V.! i) (i + s)):acc

    c :: V.Vector Int
    c = V.create $ do
      vec <- VM.replicate (e - s + 1) (0 :: Int)
      let f k = VM.unsafeModify vec (+1) (k - s)
      forM_ as f
      return vec
      -- V.freeze vec
      --V.create vec
      -- arr <- newArray (s,e) 0 :: 
      -- let f k = writeArray arr (+1) (k - s) 
    -- f :: Int -> IntMap.IntMap Int -> IntMap.IntMap Int

