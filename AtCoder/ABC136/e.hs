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
import Data.Char


main :: IO ()
main = do
  (n:k:_) <- map read . words <$> getLine :: IO [Int]
  as <- map read . words <$> getLine :: IO [Int]
  print $ solve' k as

solve' k as = head . catMaybes . map validFactor $ reverse ds
  where
    ds = sort . factors $ sum as
    validFactor d = if null . filter (\(x, y) -> x == y && x <= k ) $ zip ord rev
      then Nothing
      else Just d
      where
        -- bs = countingSort (0, d-1) $ map (`mod` d) as
        bs = sort $ map (`mod` d) as
        ord = scanl' (+) 0 bs
        rev = reverse . scanl' (\acc b -> acc + d - b)  0 . reverse $ bs    


countingSort :: (Int, Int) -> [Int] -> [Int]
countingSort (s,e) as = concatMap (\i -> replicate (c ! i) i) [s..e]
  where
    c :: UArray Int Int
    c = runSTUArray $ do
      arr <- newArray (s,e) 0
      forM_ as (\a -> do
        val <- readArray arr a
        writeArray arr a (val + 1) 
        )
      return arr
        

-- solve :: Int -> [Int] -> Int
solve k as = fst . head . filter (not.null.snd) . map numManip $ reverse ds
  where
    ds = sort . factors $ sum as
    numManip d = (
        d,  
        map fst . filter (\(x, y) -> x == y && x <= k ) $ zip ord rev
      )
      where
        bs = sort $ map (`mod` d) as
        ord = scanl' (+) 0 bs
        rev = reverse . scanl' (\acc b -> acc + d - b)  0 . reverse $ bs    


    
--factors :: (Integral a) => a -> [a]
factors = Map.foldrWithKey (\k v acc -> products (powers k v) acc) [1] . toCountMap . primeFactors

powers :: (Integral a) => a -> a -> [a]
powers n m = [ n^i | i <- [0..m]]

products :: (Num a) => [a] -> [a] -> [a]
products xs ys = [ x*y | x <- xs, y <- ys]

toCountMap :: (Ord k, Integral a) => [k] -> Map.Map k a
toCountMap xs = Map.fromListWith (+) $ zip xs (repeat 1)

primes :: Integral int => [int]
primes = wheelSieve 6

{-# SPECIALISE primes :: [Int]     #-}
{-# SPECIALISE primes :: [Integer] #-}

-- | 
-- This function returns an infinite list of prime numbers by sieving
-- with a wheel that cancels the multiples of the first @n@ primes
-- where @n@ is the argument given to @wheelSieve@. Don't use too
-- large wheels. The number @6@ is a good value to pass to this
-- function. Larger wheels improve the run time at the cost of higher
-- memory requirements.
-- 
wheelSieve :: Integral int
           => Int    -- ^ number of primes canceled by the wheel
           -> [int]  -- ^ infinite list of primes
wheelSieve k = reverse ps ++ map head (sieve p (cycle ns))
 where (p:ps,ns) = wheel k

{-# SPECIALISE wheelSieve :: Int -> [Int]     #-}
{-# SPECIALISE wheelSieve :: Int -> [Integer] #-}

-- |
-- Checks whether a given number is prime.
-- 
-- This function uses trial division to check for divisibility with
-- all primes below the square root of the given number. It is
-- impractical for numbers with a very large smallest prime factor.
-- 
isPrime :: Integral int => int -> Bool
isPrime n | n > 1     = primeFactors n == [n]
          | otherwise = False

{-# SPECIALISE isPrime :: Int     -> Bool #-}
{-# SPECIALISE isPrime :: Integer -> Bool #-}

-- |
-- Yields the sorted list of prime factors of the given positive
-- number.
-- 
-- This function uses trial division and is impractical for numbers
-- with very large prime factors.
-- 
primeFactors :: Integral int => int -> [int]
primeFactors n = factors n (wheelSieve 6)
 where
  factors 1 _                  = []
  factors m (p:ps) | m < p*p   = [m]
                   | r == 0    = p : factors q (p:ps)
                   | otherwise = factors m ps
   where (q,r) = quotRem m p

{-# SPECIALISE primeFactors :: Int     -> [Int]     #-}
{-# SPECIALISE primeFactors :: Integer -> [Integer] #-}

-- Auxiliary Definitions
------------------------------------------------------------------------------

-- Sieves prime candidates by computing composites from the result of
-- a recursive call with identical arguments. We could use sharing
-- instead of a recursive call with identical arguments but that would
-- lead to much higher memory requirements. The results of the
-- different calls are consumed at different speeds and we want to
-- avoid multiple far apart pointers into the result list to avoid
-- retaining everything in between.
--
-- Each list in the result starts with a prime. To obtain composites
-- that need to be cancelled, one can multiply all elements of the
-- list with its head.
-- 
sieve :: (Ord int, Num int) => int -> [int] -> [[int]]
sieve p ns@(m:ms) = spin p ns : sieveComps (p+m) ms (composites p ns)

{-# SPECIALISE sieve :: Int     -> [Int]     -> [[Int]]     #-}
{-# SPECIALISE sieve :: Integer -> [Integer] -> [[Integer]] #-}

-- Composites are stored in increasing order in a priority queue. The
-- queue has an associated feeder which is used to avoid filling it
-- with entries that will only be used again much later. 
-- 
type Composites int = (Queue int,[[int]])

-- The feeder is computed from the result of a call to 'sieve'.
-- 
composites :: (Ord int, Num int) => int -> [int] -> Composites int
composites p ns = (Empty, map comps (spin p ns : sieve p ns))
 where comps xs@(x:_) = map (x*) xs

{-# SPECIALISE composites :: Int     -> [Int]     -> Composites Int     #-}
{-# SPECIALISE composites :: Integer -> [Integer] -> Composites Integer #-}

-- We can split all composites into the next and remaining
-- composites. We use the feeder when appropriate and discard equal
-- entries to not return a composite twice.
-- 
splitComposites :: Ord int => Composites int -> (int,Composites int)
splitComposites (Empty, xs:xss) = splitComposites (Fork xs [], xss)
splitComposites (queue, xss@((x:xs):yss))
  | x < z     = (x, discard x (enqueue xs queue, yss))
  | otherwise = (z, discard z (enqueue zs queue', xss))
 where (z:zs,queue') = dequeue queue

{-# SPECIALISE splitComposites :: Composites Int -> (Int,Composites Int) #-}
{-# SPECIALISE
    splitComposites :: Composites Integer -> (Integer,Composites Integer) #-}

-- Drops all occurrences of the given element.
--
discard :: Ord int => int -> Composites int -> Composites int
discard n ns | n == m    = discard n ms
             | otherwise = ns
 where (m,ms) = splitComposites ns

{-# SPECIALISE discard :: Int -> Composites Int -> Composites Int #-}
{-# SPECIALISE
    discard :: Integer -> Composites Integer -> Composites Integer #-}

-- This is the actual sieve. It discards candidates that are
-- composites and yields lists which start with a prime and contain
-- all factors of the composites that need to be dropped.
--
sieveComps :: (Ord int, Num int) => int -> [int] -> Composites int -> [[int]]
sieveComps cand ns@(m:ms) xs
  | cand == comp = sieveComps (cand+m) ms ys
  | cand <  comp = spin cand ns : sieveComps (cand+m) ms xs
  | otherwise    = sieveComps cand ns ys
 where (comp,ys) = splitComposites xs

{-# SPECIALISE sieveComps :: Int -> [Int] -> Composites Int -> [[Int]] #-}
{-# SPECIALISE
    sieveComps :: Integer -> [Integer] -> Composites Integer -> [[Integer]] #-}

-- This function computes factors of composites of primes by spinning
-- a wheel.
-- 
spin :: Num int => int -> [int] -> [int]
spin x (y:ys) = x : spin (x+y) ys

{-# SPECIALISE spin :: Int     -> [Int]     -> [Int]     #-}
{-# SPECIALISE spin :: Integer -> [Integer] -> [Integer] #-}

-- A wheel consists of a list of primes whose multiples are canceled
-- and the actual wheel that is rolled for canceling.
--
type Wheel int = ([int],[int])

-- Computes a wheel that cancels the multiples of the given number
-- (plus 1) of primes.
--
-- For example:
--
-- wheel 0 = ([2],[1])
-- wheel 1 = ([3,2],[2])
-- wheel 2 = ([5,3,2],[2,4])
-- wheel 3 = ([7,5,3,2],[4,2,4,2,4,6,2,6])
--
wheel :: Integral int => Int -> Wheel int
wheel n = iterate next ([2],[1]) !! n

{-# SPECIALISE wheel :: Int -> Wheel Int     #-}
{-# SPECIALISE wheel :: Int -> Wheel Integer #-}

next :: Integral int => Wheel int -> Wheel int
next (ps@(p:_),xs) = (py:ps,cancel (product ps) p py ys)
 where (y:ys) = cycle xs
       py = p + y

{-# SPECIALISE next :: Wheel Int     -> Wheel Int     #-}
{-# SPECIALISE next :: Wheel Integer -> Wheel Integer #-}

cancel :: Integral int => int -> int -> int -> [int] -> [int]
cancel 0 _ _ _ = []
cancel m p n (x:ys@(y:zs))
  | nx `mod` p > 0 = x : cancel (m-x) p nx ys
  | otherwise      = cancel m p n (x+y:zs)
 where nx = n + x

{-# SPECIALISE cancel :: Int -> Int -> Int -> [Int] -> [Int] #-}
{-# SPECIALISE
    cancel :: Integer -> Integer -> Integer -> [Integer] -> [Integer] #-}

-- We use a special version of priority queues implemented as /pairing/
-- /heaps/ (see /Purely Functional Data Structures/ by Chris Okasaki).
--
-- The queue stores non-empty lists of composites; the first element
-- is used as priority.
--
data Queue int = Empty | Fork [int] [Queue int]

enqueue :: Ord int => [int] -> Queue int -> Queue int
enqueue ns = merge (Fork ns [])

{-# SPECIALISE enqueue :: [Int]     -> Queue Int     -> Queue Int     #-}
{-# SPECIALISE enqueue :: [Integer] -> Queue Integer -> Queue Integer #-}

merge :: Ord int => Queue int -> Queue int -> Queue int
merge Empty y                        = y
merge x     Empty                    = x
merge x     y     | prio x <= prio y = join x y
                  | otherwise        = join y x
 where prio (Fork (n:_) _) = n
       join (Fork ns qs) q = Fork ns (q:qs)

{-# SPECIALISE merge :: Queue Int     -> Queue Int     -> Queue Int     #-}
{-# SPECIALISE merge :: Queue Integer -> Queue Integer -> Queue Integer #-}

dequeue :: Ord int => Queue int -> ([int], Queue int)
dequeue (Fork ns qs) = (ns,mergeAll qs)

{-# SPECIALISE dequeue :: Queue Int     -> ([Int],     Queue Int)     #-}
{-# SPECIALISE dequeue :: Queue Integer -> ([Integer], Queue Integer) #-}

mergeAll :: Ord int => [Queue int] -> Queue int
mergeAll []       = Empty
mergeAll [x]      = x
mergeAll (x:y:qs) = merge (merge x y) (mergeAll qs)

{-# SPECIALISE mergeAll :: [Queue Int]     -> Queue Int     #-}
{-# SPECIALISE mergeAll :: [Queue Integer] -> Queue Integer #-}