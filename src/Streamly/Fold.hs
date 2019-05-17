{-# LANGUAGE BangPatterns              #-}
{-# LANGUAGE CPP                       #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- |
-- Module      : Streamly.Fold
-- Copyright   : (c) 2019 Composewell Technologies
--               (c) 2013 Gabriel Gonzalez
-- License     : BSD3
-- Maintainer  : harendra.kumar@gmail.com
-- Stability   : experimental
-- Portability : GHC
--
-- Left folds that can be composed into a single fold. The composed fold
-- distributes the same input to the indvidual folds and combines there output
-- in a single output.  Also see the "Streamly.Sink" module that provides
-- specialized left folds that discard the outputs.
--
-- > import qualified as FL
--
--
-- A left fold is represented by the type 'Fold'. @Fold m a b@ folds an
-- input stream consisting of values of type @a@ to a singleton value of type
-- @b@. The fold can be run using 'foldl'.
--
-- >>> FL.foldl FL.sum (S.enumerateFromTo 1 100)
-- 5050

-- To give you an idea about different types involved in stream procesisng,
-- here is a diagram showing how a general stream processing pipeline looks
-- like:
--
-- @
-- Stream m a ---- Scan m a b ----- Fold m b a --- Sink m b
-- @
--
-- @Stream m a@ is a generator of values of type @a@. @Scan m a b@ is a
-- composable stream transformer that can generate, transform and merge
-- streams. @Fold m b a@ is a dual of scan, it is a composable stream fold
-- that can split, transform and fold streams and combine the results. @Sink m
-- a@ sits on the opposite side of stream m a, it is a consumer of streams that
-- produces nothing.
--
-- A 'Fold' can be converted to a stream using 'scanl'.

-- IMPORTANT: keep the signatures consistent with the folds in Streamly.Prelude

module Streamly.Fold
    (
    -- * Introduction
    -- ** Composition
    -- $composable

    -- ** Transformation
    -- $inputOutput

    -- ** Full vs Partial Folds
    -- $termination

    -- * Fold Type
      Fold (..)

    -- * Combinators
    -- ** Folding
    , foldl

    -- ** Scanning
    , scanl
    , postscanl

    -- ** Spanning
    -- | Spanning splits the input into two groups and applies two different
    -- folds on each group.

    -- Element unaware spanning
    , splitAt

    -- Element aware spanning
    , span
    , break
    , spanBy
    , spanRollingBy
    , spanned

    -- ** Grouping
    -- | Grouping splits the stream into N groups and applies the same fold on
    -- each group.
    --
    -- @
    --
    -- ----stream m a----|-Fold a b-|-Fold a b-|-...-|----Stream m b
    --
    -- @

    -- In imperative terms grouped folding can be considered as a nested loop
    -- where we loop over the stream to group elements and then loop over
    -- individual groups to fold them to a single value that is yielded in the
    -- output stream.
    --
    -- Note that these grouping folds are true streaming folds that never
    -- accumulate the group in memory before folding, i.e. the group elements
    -- are consumed by the folds as they are yielded by the stream. Therefore,
    -- the whole computation runs in constant space.
    -- In contrast, we can simply use a scan on the stream to buffer the whole
    -- groups in memory and then map a fold on it to fold the groups. This kind
    -- of grouping and folding would not work well when the group size is big.

    -- Element unaware grouping
    , groupsOf
    -- , arrayGroupsOf

    -- Element aware grouping
    , groups
    , groupsBy
    , groupsRollingBy
    , grouped

    -- ** Splitting by an Element
    , splitBy
    , splitSuffixBy
    -- , splitPrefixBy
    , wordsBy

    -- ** Splitting on a Sequence
    , splitOn
    , splitSuffixOn
    -- , splitPrefixOn
    , wordsOn

    -- Keeping the delimiters
    , splitOn'
    , splitSuffixOn'
    -- , splitPrefixOn'

    -- Splitting by multiple sequences
    -- , splitOnAny
    -- , splitSuffixOnAny
    -- , splitPrefixOnAny

    -- ** Distributing
    -- |
    -- The 'Applicative' instance of 'Fold' can be used to distribute one copy
    -- of the stream to each fold and zip the results using a function.
    --
    -- @
    --
    --                 |-------Fold m a b--------|
    -- ---stream m a---|                          |---m (b,c,...)
    --                 |-------Fold m a c--------|
    --                 |                          |
    --                            ...
    -- @
    --
    -- >>> FL.foldl ((,) <$> FL.sum <*> FL.length) (S.enumerateFromTo 1.0 100.0)
    -- (5050.0,100)
    --
    , tee
    , distribute

    -- ** Demultiplexing
    -- |
    -- Direct items in the input stream to different folds using a function to
    -- select the fold. This is useful to demultiplex the input stream.
    , partitionByM
    , partitionBy

    -- ** Unzipping
    , unzipM
    , unzip

    -- ** Resuming
    , duplicate

    -- * Input Transformation
    -- | Transformations can be applied on a fold before folding the input.
    -- Note that unlike transformations on streams, transformations on folds
    -- are applied on the input side of the fold. In other words these are
    -- contravariant mappings though the names are identical to covariant
    -- versions to keep them short and consistent with covariant versions.
    -- For that reason, these operations are prefixed with 'l' for 'left'.

    -- , lscanl'
    -- , lscanlM'
    -- , lpostscanl'
    -- , lpostscanlM'
    -- , lprescanl'
    -- , lprescanlM'
    -- , lscanl1'
    -- , lscanl1M'

    -- ** Mapping
    -- | Map is a strictly one-to-one transformation of stream elements. It
    -- cannot add or remove elements from the stream, just transforms them.
    , lmap

    -- ** Flattening
    --, sequence
    , lmapM

    -- ** Nesting
    -- , concatMap
    -- , groupsOf

    -- ** Filtering
    -- | Filtering may remove some elements from the stream.

    , lfilter
    , lfilterM
    , ltake
    , ltakeWhile
    {-
    , ltakeWhileM
    , ldrop
    , ldropWhile
    , ldropWhileM
    , ldeleteBy
    , luniq

    -- ** Insertion
    -- | Insertion adds more elements to the stream.

    , linsertBy
    , lintersperseM

    -- ** Reordering
    , lreverse

    -- * Hybrid Operations

    -- ** Map and Filter
    , lmapMaybe
    , lmapMaybeM

    -- ** Scan and filter
    , lfindIndices
    , lelemIndices
    -}

    -- * Partial Folds
    -- ** To Elements
    -- | Folds that extract selected elements of a stream or properties
    -- thereof.

    -- , (!!)
    -- , genericIndex
    , index
    , head
    -- , findM
    , find
    , findIndex
    , elemIndex
    , lookup

    -- -- ** To Parts
    -- -- | Folds that extract selected parts of a stream.
    -- , tail
    -- , init

    -- ** To Boolean
    -- | Folds that test absence or presence of elements.
    , null
    , elem
    , notElem

    -- XXX these are slower than right folds even when full input is used
    -- ** To Summary (Boolean)
    -- | Folds that summarize the stream to a boolean value.
    , all
    , any
    , and
    , or

    -- * Full Folds
    -- ** Run Effects
    , drain
    -- , drainN
    -- , drainWhile

    -- ** Monoidal Folds
    , mconcat
    , foldMap
    , foldMapM

    -- ** To Summary
    -- | Folds that summarize the stream to a single value.
    , length
    , sum
    , product

    -- ** To Summary (Statistical)
    , mean
    , variance
    , stdDev

    -- ** To Summary (Maybe)
    -- | Folds that summarize a non-empty stream to a 'Just' value and return
    -- 'Nothing' for an empty stream.
    , last
    , maximumBy
    , maximum
    , minimumBy
    , minimum
    -- , the

    -- ** To Containers
    -- | Convert or serialize a stream into an output structure or container.

    -- XXX toList is slower than the custom (Streamly.Prelude.toList)
    -- implementation
    , toList
    , toRevList
    , toStream
    , toArrayN

    -- * Splitter scans
    -- | Scans that can be used to split and fold a stream using
    -- 'foldGroupWith'.
    , newline
    )
where

import Control.Monad.IO.Class (MonadIO(..))
import Foreign.Storable (Storable(..))
import System.IO.Unsafe (unsafeDupablePerformIO)
import Prelude
       hiding (filter, drop, dropWhile, take, takeWhile, zipWith, foldr,
               foldl, map, mapM, mapM_, sequence, all, any, sum, product, elem,
               notElem, maximum, minimum, head, last, tail, length, null,
               reverse, iterate, init, and, or, lookup, foldr1, (!!),
               scanl, scanl1, replicate, concatMap, mconcat, foldMap, unzip,
               span, splitAt, break)

import Streamly.Array.Types
       (Array(..), unsafeDangerousPerformIO, unsafeNew, unsafeAppend)
import Streamly.Fold.Types (Fold(..), Pair'(..))
import Streamly.Parse.Types (Parse(..), Status(..))
import Streamly.Streams.Serial (SerialT)
import Streamly.Streams.StreamK (IsStream())

import Streamly (MonadAsync)
import qualified Streamly.Prelude as S
import qualified Streamly.Streams.StreamD as D
import qualified Streamly.Streams.StreamK as K
import qualified Streamly.Streams.Prelude as P

-- $termination
--
-- We can use the left folds in this module instead of the folds in
-- "Streamly.Prelude". For example the following two ways of folding are
-- equivalent in functionality and performance,
--
-- >>> FL.foldl FL.sum (S.enumerateFromTo 1 100)
-- 5050
-- >>> S.sum (S.enumerateFromTo 1 100)
-- 5050
--
-- However, left folds are push type folds. That means we push the entire input
-- to a fold before we can get the output.  Therefore, the performance is
-- equivalent only for full folds like 'sum' and 'length'. For partial folds
-- like 'head' or 'any' the folds in "Streamly.Prelude" may be much more
-- efficient because they are implemented as right folds that terminate as soon
-- as we get the result. Note that when a full fold is composed with a partial
-- fold in parallel the performance is not impacted as we anyway have to
-- consume the whole stream due to the full fold.
--
-- >>> S.head (1 `S.cons` undefined)
-- Just 1
-- >>> FL.foldl FL.head (1 `S.cons` undefined)
-- *** Exception: Prelude.undefined
--
-- However, we can wrap the fold in a scan to convert it into a lazy stream of
-- fold steps. We can then terminate the stream whenever we want.  For example,
--
-- >>> S.toList $ S.take 1 $ FL.scanl FL.head (1 `S.cons` undefined)
-- [Nothing]
--
-- The following example extracts the input stream up to a point where the
-- running average of elements is no more than 10:
--
-- >>>  S.toList
-- >>> $ S.map (fromJust . fst)
-- >>> $ S.takeWhile (\(_,x) -> x <= 10)
-- >>> $ FL.postscanl ((,) <$> FL.last <*> avg) (S.enumerateFromTo 1.0 100.0)
--  [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0,19.0]

-- $composable
-- Multiple left folds can be composed using 'Applicative' composition giving a
-- single composed left fold that distributes its input to all the folds in the
-- composition and combines the outputs using the 'Applicative':
--
-- >>> let avg = (/) \<$> FL.sum \<*> fmap fromIntegral FL.length
-- >>> FL.foldl avg (S.enumerateFromTo 1.0 100.0)
-- 50.5
--
-- Composing with 'Monoid':
--
-- >>> FL.foldl (FL.head <> FL.last) (fmap Sum $ S.enumerateFromTo 1.0 100.0)
-- Just (Sum {getSum = 101.0})
--

-- $inputOutput
--
-- Unlike stream producers, folds have an input side as well as an output side.
-- In the type @Fold m a b@, @a@ is the input and @b@ is the output.
-- Transformations can be applied either on the input side or on the output
-- side. The 'Functor' instance of a fold maps on the output of the fold:
--
-- >>> FL.foldl (fmap show FL.sum) (S.enumerateFromTo 1 100)
-- "5050"
--
-- Combinators like 'lmap' and 'lfilter' transform the input stream of the
-- fold. The prefix 'l' stands for the /left/ side.
--
-- >>> FL.foldl (FL.lmap (\x -> x * x) FL.sum) (S.enumerateFromTo 1 100)
-- 338350

------------------------------------------------------------------------------
-- Scanning with a Fold
------------------------------------------------------------------------------

-- | Scan a stream using the given monadic fold.
{-# INLINE scanl #-}
scanl :: Monad m => Fold m a b -> SerialT m a -> SerialT m b
scanl (Fold step begin done) = P.scanxM' step begin done

-- | Postscan a stream using the given monadic fold.
{-# INLINE postscanl #-}
postscanl :: Monad m => Fold m a b -> SerialT m a -> SerialT m b
postscanl (Fold step begin done) = P.postscanxM' step begin done

-- XXX toPrescanl

------------------------------------------------------------------------------
-- Running a Fold
------------------------------------------------------------------------------

-- | Fold a stream using the supplied monadic fold.
--
-- >>> FL.foldl FL.sum (S.enumerateFromTo 1 100)
-- 5050
{-# INLINE foldl #-}
foldl :: Monad m => Fold m a b -> SerialT m a -> m b
foldl (Fold step begin done) = P.foldxM' step begin done

------------------------------------------------------------------------------
-- Composing folds
------------------------------------------------------------------------------

-- XXX have a wye on the production side to merge two streams fairly? wye would
-- be the interleave or parallel merge operation. A dual of tee in some sense.
-- XXX What is the production side dual of this? mapM?
--
-- | Distribute one copy of the stream to each fold and zip the results.
--
-- @
--                 |-------Fold m a b--------|
-- ---stream m a---|                          |---m (b,c)
--                 |-------Fold m a c--------|
-- @
-- >>> FL.foldl (FL.tee FL.sum FL.length) (S.enumerateFromTo 1.0 100.0)
-- (5050.0,100)
--
tee :: Monad m => Fold m a b -> Fold m a c -> Fold m a (b,c)
tee f1 f2 = (,) <$> f1 <*> f2

-- XXX we can unify Fold and Scan types. In fact a fold is a special case of
-- scan where we filter out all other elements except the last one. We can
-- perhaps do an efficient fold with a scan type as well?

{-# INLINE foldNil #-}
foldNil :: Monad m => Fold m a [b]
foldNil = Fold step begin done  where
  begin = return []
  step _ _ = return []
  done = return

-- XXX we can directly use an Array as the accumulator so that this can scale
-- very well to a large number of elements.
{-# INLINE foldCons #-}
foldCons :: Monad m => Fold m a b -> Fold m a [b] -> Fold m a [b]
foldCons (Fold stepL beginL doneL) (Fold stepR beginR doneR) =
    Fold step begin done

    where

    begin = Pair' <$> beginL <*> beginR
    step (Pair' xL xR) a = Pair' <$> stepL xL a <*> stepR xR a
    done (Pair' xL xR) = (:) <$> (doneL xL) <*> (doneR xR)

-- | Distribute one copy of the stream to each fold and collect the results in
-- a container.
--
-- @
--
--                 |-------Fold m a b--------|
-- ---stream m a---|                          |---m (Array b)
--                 |-------Fold m a b--------|
--                 |                          |
--                            ...
-- @
--
-- >>> FL.foldl (FL.distribute [FL.sum, FL.length]) (S.enumerateFromTo 1 5)
-- [15,5]
--
-- This is the consumer side dual of the producer side 'sequence' operation.
{-# INLINE distribute #-}
distribute :: Monad m => [Fold m a b] -> Fold m a [b]
distribute [] = foldNil
distribute (x:xs) = foldCons x (distribute xs)

{-
{-# INLINE foldCons_ #-}
foldCons_ :: Monad m => Fold m a () -> Fold m a () -> Fold m a ()
foldCons_ (Fold stepL beginL _) (Fold stepR beginR _) =

    Fold step begin done

    where

    -- Since accumulator type of this fold is known to be (), we know that
    -- this will not use the accumulator.
    begin = beginL >> beginR >> return ()
    step () a = do
        void $ stepL undefined a
        void $ stepR undefined a
        return ()
    done = return

-- XXX folding pairwise hierarcically may be more efficient
-- XXX use array instead of list for scalability
-- distribute_ :: Monad m => Array (Fold m a b) -> Fold m a ()

-- | Distribute a stream to a list of folds.
--
-- >> FL.foldl (FL.distribute_ [FL.mapM_ print, FL.mapM_ (print . (+10))]) (S.enumerateFromTo 1 5)
distribute_ :: Monad m => [Fold m a ()] -> Fold m a ()
distribute_ [] = drain
distribute_ (x:xs) = foldCons_ x (distribute_ xs)
    -}

-- XXX need to transfer the state from up stream to the down stream fold when
-- folding.

-- | Partition the input over two folds using an 'Either' partitioning
-- predicate.
--
-- @
--
--                                     |-------Fold b x--------|
-- -----stream m a --> (Either b c)----|                       |----(x,y)
--                                     |-------Fold c y--------|
-- @
--
-- Send input to either fold randomly:
--
-- >>> randomly a = randomIO >>= \x -> return $ if x then Left a else Right a
-- >>> FL.foldl (FL.partitionByM randomly FL.length FL.length) (S.enumerateFromTo 1 100)
-- (59,41)
--
-- Send input to the two folds in a proportion of 2:1:
--
-- @
-- proportionately m n = do
--  ref <- newIORef $ cycle $ concat [replicate m Left, replicate n Right]
--  return $ \\a -> do
--      r <- readIORef ref
--      writeIORef ref $ tail r
--      return $ head r a
--
-- main = do
--  f <- proportionately 2 1
--  r <- FL.foldl (FL.partitionByM f FL.length FL.length) (S.enumerateFromTo (1 :: Int) 100)
--  print r
-- @
-- @
-- (67,33)
-- @
--
-- This is the consumer side dual of the producer side 'mergeBy' operation.
--
{-# INLINE partitionByM #-}
partitionByM :: Monad m
    => (a -> m (Either b c)) -> Fold m b x -> Fold m c y -> Fold m a (x, y)
partitionByM f (Fold stepL beginL doneL) (Fold stepR beginR doneR) =

    Fold step begin done

    where

    begin = Pair' <$> beginL <*> beginR
    step (Pair' xL xR) a = do
        r <- f a
        case r of
            Left b -> Pair' <$> stepL xL b <*> return xR
            Right c -> Pair' <$> return xL <*> stepR xR c
    done (Pair' xL xR) = (,) <$> doneL xL <*> doneR xR

-- XXX we can use (a -> Bool) instead of (a -> Either b c), but the latter
-- makes the signature clearer as to which case belongs to which fold.

-- | Same as 'partitionByM' but with a pure partition function.
--
-- Count even and odd numbers in a stream:
--
-- @
-- >>> let f = FL.partitionBy (\\n -> if even n then Left n else Right n)
--                       (fmap (("Even " ++) . show) FL.length)
--                       (fmap (("Odd "  ++) . show) FL.length)
--   in FL.foldl f (S.enumerateFromTo 1 100)
-- ("Even 50","Odd 50")
-- @
--
{-# INLINE partitionBy #-}
partitionBy :: Monad m
    => (a -> Either b c) -> Fold m b x -> Fold m c y -> Fold m a (x, y)
partitionBy f = partitionByM (return . f)

-- Send one item to each fold in a round-robin fashion. This is the consumer
-- side dual of producer side 'mergeN' operation.
-- partitionN :: Monad m => [Fold m a b] -> Fold m a [b]
-- partitionN fs = Fold step begin done

-- XXX rename this to unzipWithM and make unzipM as
-- unzipM :: Monad m => Fold m b x -> Fold m c y -> Fold m (b,c) (x,y)

-- Demultiplex an input element into a number of typed variants. We want to
-- statically restrict the target values within a set of predefined types, an
-- enumeration of a GADT. We also want to make sure that the Map contains only
-- those types and the full set of those types.  Instead of Map it should
-- probably be a lookup-table using a Array/array and not in GC memory.
--
-- This is the consumer side dual of the producer side 'mux' operation.
-- demux :: (Monad m, Ord k)
--     => (a -> k) -> Map k (Fold m a b) -> Fold m a (Map k b)
-- demux f kv = Fold step begin done

-- | Split elements in the input stream into multiple parts using a splitter
-- function, direct each part to a different fold and zip the results.
--
-- @
--
--                           |-------Fold a x--------|
-- -----Stream m x----(a,b)--|                       |----m (x,y)
--                           |-------Fold b y--------|
--
-- @
--
-- This is the consumer side dual of the producer side 'zip' operation.
--
{-# INLINE unzipM #-}
unzipM :: Monad m
    => (a -> m (b,c)) -> Fold m b x -> Fold m c y -> Fold m a (x,y)
unzipM f (Fold stepL beginL doneL) (Fold stepR beginR doneR) =
    Fold step begin done

    where

    step (Pair' xL xR) a = do
        (b,c) <- f a
        Pair' <$> stepL xL b <*> stepR xR c
    begin = Pair' <$> beginL <*> beginR
    done (Pair' xL xR) = (,) <$> doneL xL <*> doneR xR

-- | Same as 'unzipM' but with a pure unzip function.
--
{-# INLINE unzip #-}
unzip :: Monad m
    => (a -> (b,c)) -> Fold m b x -> Fold m c y -> Fold m a (x,y)
unzip f = unzipM (return . f)

-- | Modify the fold such that when the fold is done, instead of returning the
-- accumulator, it returns a fold. The returned fold starts from where we left
-- i.e. it uses the last accumulator value as the initial value of the
-- accumulator. Thus we can resume the fold later and feed it more input.
--
-- >> do
-- >    more <- FL.foldl (FL.duplicate FL.sum) (S.enumerateFromTo 1 10)
-- >    evenMore <- FL.foldl (FL.duplicate more) (S.enumerateFromTo 11 20)
-- >    FL.foldl evenMore (S.enumerateFromTo 21 30)
-- > 465
{-# INLINABLE duplicate #-}
duplicate :: Applicative m => Fold m a b -> Fold m a (Fold m a b)
duplicate (Fold step begin done) =
    Fold step begin (\x -> pure (Fold step (pure x) done))

------------------------------------------------------------------------------
-- Notes on concurrency
------------------------------------------------------------------------------

-- We need a buffering approach for parallel folds, carve out buffers from the
-- producer. Each buffer would have a reference count and these buffers can be
-- queued independently to the queues of different consumers. These buffers
-- could be vectors, we just need a refcount too. If the buffers are small then
-- the overhead will be higher. This is similar to the non-concurrent composing
-- approach except that the values being given to folds are refcounted vectors
-- rather than single elements.
--
-- For non-buffering case we can use multiple SVars and queue the values to
-- each SVar. Each fold would be pulling the from its own SVar. We can use the
-- foldl's Fold type with a parally combinator, in that case the fold would
-- automatically distribute the values via SVar.

------------------------------------------------------------------------------
-- Transformations on fold inputs
------------------------------------------------------------------------------

-- | @(lmap f fold)@ maps the function @f@ on the input of the fold.
--
-- >>> FL.foldl (lmap Sum mconcat) [1..10]
-- Sum {getSum = 55}
--
{-# INLINABLE lmap #-}
lmap :: (a -> b) -> Fold m b r -> Fold m a r
lmap f (Fold step begin done) = Fold step' begin done
  where
    step' x a = step x (f a)

-- | @(lmapM f fold)@ maps the monadic function @f@ on the input of the fold.
{-# INLINABLE lmapM #-}
lmapM :: Monad m => (a -> m b) -> Fold m b r -> Fold m a r
lmapM f (Fold step begin done) = Fold step' begin done
  where
    step' x a = f a >>= step x

------------
-- Nesting
------------

{-
-- | This can be used to apply all the stream generation operations on folds.
lconcatMap ::(IsStream t, Monad m) => (a -> t m b)
    -> Fold m b c
    -> Fold m a c
lconcatMap s f1 f2 = undefined
-}

{-
-- | Group the input elements of a fold by some criterion and fold each group
-- using a given fold before its fed to the final fold.
--
-- For example, we can copy and distribute a stream to multiple folds and then
-- in each fold we can group the input differently e.g. by one second, one
-- minute and one hour windows respectively and fold each resulting stream of
-- folds.
--
-- @
--
-- -----Fold m a b----|-Fold n a c-|-Fold n a c-|-...-|----Fold m a c
--
-- @
lgroupsOf :: Int -> Fold m a b -> Fold m b c -> Fold m a c
lgroupsOf n f1 f2 = undefined
-}

-------------
-- Filtering
-------------

-- | @lfilter p fold@ applies a filter using predicate @p@ to the input of a
-- fold.
--
-- >>> FL.foldl (lfilter (> 5) FL.sum) [1..10]
-- 40
--
{-# INLINABLE lfilter #-}
lfilter :: Monad m => (a -> Bool) -> Fold m a r -> Fold m a r
lfilter f (Fold step begin done) = Fold step' begin done
  where
    step' x a = if f a then step x a else return x

-- | @lfilterM p fold@ applies a filter using a monadic predicate @p@ to the
-- input of a fold.
--
{-# INLINABLE lfilterM #-}
lfilterM :: Monad m => (a -> m Bool) -> Fold m a r -> Fold m a r
lfilterM f (Fold step begin done) = Fold step' begin done
  where
    step' x a = do
      use <- f a
      if use then step x a else return x

{-# INLINABLE ltake #-}
ltake :: Monad m => Int -> Fold m a b -> Fold m a b
ltake n (Fold step initial done) = Fold step' initial' done'
    where
    initial' = fmap (Pair' 0) initial
    step' (Pair' i r) a = do
        if i < n
        then do
            res <- step r a
            return $ Pair' (i + 1) res
        else return $ Pair' i r
    done' (Pair' _ r) = done r

-- | Takes elements from the input as long as the predicate succeeds.
{-# INLINABLE ltakeWhile #-}
ltakeWhile :: Monad m => (a -> Bool) -> Fold m a b -> Fold m a b
ltakeWhile predicate (Fold step initial done) = Fold step' initial' done'
    where
    initial' = fmap Left' initial
    step' (Left' r) a = do
        if predicate a
        then fmap Left' $ step r a
        else return (Right' r)
    step' r _ = return r
    done' (Left' r) = done r
    done' (Right' r) = done r

------------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------------

data Pair3' a b c = Pair3' !a !b !c

-- | A strict 'Maybe'
data Maybe' a = Just' !a | Nothing'

-- | Convert 'Maybe'' to 'Maybe'
{-# INLINABLE lazy #-}
lazy :: Monad m => Maybe' a -> m (Maybe a)
lazy  Nothing' = return $ Nothing
lazy (Just' a) = return $ Just a

-- | A strict 'Either'
data Either' a b = Left' !a | Right' !b

-- | Convert 'Either'' to 'Maybe'
{-# INLINABLE hush #-}
hush :: Either' a b -> Maybe b
hush (Left'  _) = Nothing
hush (Right' b) = Just b

-- | @_Fold1 step@ returns a new 'Fold' using just a step function that has the
-- same type for the accumulator and the element. The result type is the
-- accumulator type wrapped in 'Maybe'. The initial accumulator is retrieved
-- from the 'Foldable', the result is 'None' for empty containers.
{-# INLINABLE _Fold1 #-}
_Fold1 :: Monad m => (a -> a -> a) -> Fold m a (Maybe a)
_Fold1 step = Fold step_ (return Nothing') lazy
  where
    step_ mx a = return $ Just' $
        case mx of
            Nothing' -> a
            Just' x -> step x a

------------------------------------------------------------------------------
-- Left folds
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Monoidal left folds
------------------------------------------------------------------------------

-- | Left fold a monoidal input using 'mappend' and 'mempty'.
--
-- > FL.foldl FL.mconcat (S.map Sum $ S.enumerateFromTo 1 10)
--
{-# INLINABLE mconcat #-}
mconcat :: (Monad m, Monoid a) => Fold m a a
mconcat = Fold (\x a -> return $ mappend x a) (return mempty) return

-- |
-- > foldMap f = map f mconcat
--
-- Make a fold from a pure function that folds the output of the function
-- using 'mappend' and 'mempty'.
--
-- > FL.foldl (FL.foldMap Sum) $ S.enumerateFromTo 1 10
--
{-# INLINABLE foldMap #-}
foldMap :: (Monad m, Monoid b) => (a -> b) -> Fold m a b
foldMap f = lmap f mconcat

-- |
-- > foldMapM f = mapM f mconcat
--
-- Make a fold from a monadic function that folds the output of the function
-- using 'mappend' and 'mempty'.
--
-- > FL.foldM (FL.foldMapM (return . Sum)) $ S.enumerateFromTo 1 10
--
{-# INLINABLE foldMapM #-}
foldMapM ::  (Monad m, Monoid b) => (a -> m b) -> Fold m a b
foldMapM act = Fold step begin done
    where
    done = return
    begin = return mempty
    step m a = do
        m' <- act a
        return $! mappend m m'

------------------------------------------------------------------------------
-- Run Effects
------------------------------------------------------------------------------

-- | A fold that drains all its input, running the effects and discarding the
-- results.
{-# INLINABLE drain #-}
drain :: Monad m => Fold m a ()
drain = Fold step begin done
    where
    begin = return ()
    step _ _ = return ()
    done = return

------------------------------------------------------------------------------
-- To Elements
------------------------------------------------------------------------------

-- | Like 'index', except with a more general 'Integral' argument
{-# INLINABLE genericIndex #-}
genericIndex :: (Integral i, Monad m) => i -> Fold m a (Maybe a)
genericIndex i = Fold step (return $ Left' 0) done
  where
    step x a = return $
        case x of
            Left'  j -> if i == j
                        then Right' a
                        else Left' (j + 1)
            _        -> x
    done x = return $
        case x of
            Left'  _ -> Nothing
            Right' a -> Just a

-- | @(index n)@ returns the @n@th element of the container, or 'Nothing' if
-- the container has an insufficient number of elements
{-# INLINABLE index #-}
index :: Monad m => Int -> Fold m a (Maybe a)
index = genericIndex

-- | Get the first element of a container or return 'Nothing' if the container
-- is empty
{-# INLINABLE head #-}
head :: Monad m => Fold m a (Maybe a)
head = _Fold1 const

-- | Get the last element of a container or return 'Nothing' if the container
-- is empty
{-# INLINABLE last #-}
last :: Monad m => Fold m a (Maybe a)
last = _Fold1 (flip const)

-- | @(find predicate)@ returns the first element that satisfies the predicate
-- or 'Nothing' if no element satisfies the predicate
{-# INLINABLE find #-}
find :: Monad m => (a -> Bool) -> Fold m a (Maybe a)
find predicate = Fold step (return Nothing') lazy
  where
    step x a = return $
        case x of
            Nothing' -> if predicate a
                        then Just' a
                        else Nothing'
            _        -> x

-- | @(findIndex predicate)@ returns the index of the first element that
-- satisfies the predicate, or 'Nothing' if no element satisfies the predicate
{-# INLINABLE findIndex #-}
findIndex :: Monad m => (a -> Bool) -> Fold m a (Maybe Int)
findIndex predicate = Fold step (return $ Left' 0) (return . hush)
  where
    step x a = return $
        case x of
            Left' i ->
                if predicate a
                then Right' i
                else Left' (i + 1)
            _       -> x

-- | @(elemIndex a)@ returns the index of the first element that equals @a@, or
-- 'Nothing' if no element matches
{-# INLINABLE elemIndex #-}
elemIndex :: (Eq a, Monad m) => a -> Fold m a (Maybe Int)
elemIndex a = findIndex (a ==)

-- | @(lookup a)@ returns the element paired with the first matching item, or
-- 'Nothing' if none matches
{-# INLINABLE lookup #-}
lookup :: (Eq a, Monad m) => a -> Fold m (a,b) (Maybe b)
lookup a0 = Fold step (return Nothing') lazy
  where
    step x (a,b) = return $
        case x of
            Nothing' -> if a == a0
                        then Just' b
                        else Nothing'
            _ -> x

------------------------------------------------------------------------------
-- To Boolean
------------------------------------------------------------------------------

-- | Returns 'True' if the container is empty, 'False' otherwise
{-# INLINABLE null #-}
null :: Monad m => Fold m a Bool
null = Fold (\_ _ -> return False) (return True) return

-- |
-- > any p = map p or
--
-- @any predicate@ returns 'True' if any element satisfies the predicate,
-- 'False' otherwise
{-# INLINABLE any #-}
any :: Monad m => (a -> Bool) -> Fold m a Bool
any predicate = Fold (\x a -> return $ x || predicate a) (return False) return

-- | @(elem a)@ returns 'True' if the container has an element equal to @a@,
-- 'False' otherwise
{-# INLINABLE elem #-}
elem :: (Eq a, Monad m) => a -> Fold m a Bool
elem a = any (a ==)

-- |
-- > all p = map p and
--
-- @all predicate@ returns 'True' if all elements satisfy the predicate,
-- 'False' otherwise
{-# INLINABLE all #-}
all :: Monad m => (a -> Bool) -> Fold m a Bool
all predicate = Fold (\x a -> return $ x && predicate a) (return True) return

-- | @(notElem a)@ returns 'False' if the container has an element equal to
-- @a@, 'True' otherwise
{-# INLINABLE notElem #-}
notElem :: (Eq a, Monad m) => a -> Fold m a Bool
notElem a = all (a /=)

-- | Returns 'True' if all elements are 'True', 'False' otherwise
{-# INLINABLE and #-}
and :: Monad m => Fold m Bool Bool
and = Fold (\x a -> return $ x && a) (return True) return

-- | Returns 'True' if any element is 'True', 'False' otherwise
{-# INLINABLE or #-}
or :: Monad m => Fold m Bool Bool
or = Fold (\x a -> return $ x || a) (return False) return

------------------------------------------------------------------------------
-- To Summary
------------------------------------------------------------------------------

-- | Like 'length', except with a more general 'Num' return value
{-# INLINABLE genericLength #-}
genericLength :: (Monad m, Num b) => Fold m a b
genericLength = Fold (\n _ -> return $ n + 1) (return 0) return

-- | Return the length of the container
{-# INLINABLE length #-}
length :: Monad m => Fold m a Int
length = genericLength

-- | Computes the sum of all elements
{-# INLINABLE sum #-}
sum :: (Monad m, Num a) => Fold m a a
sum = Fold (\x a -> return $ x + a) (return 0) return

-- | Computes the product of all elements
{-# INLINABLE product #-}
product :: (Monad m, Num a) => Fold m a a
product = Fold (\x a -> return $ x * a) (return 1) return

------------------------------------------------------------------------------
-- To Summary (Statistical)
------------------------------------------------------------------------------

-- | Compute a numerically stable arithmetic mean of all elements
{-# INLINABLE mean #-}
mean :: (Monad m, Fractional a) => Fold m a a
mean = Fold step (return begin) (return . done)
  where
    begin = Pair' 0 0
    step (Pair' x n) y = return $
        let n' = n + 1
        in Pair' (x + (y - x) / n') n'
    done (Pair' x _) = x

-- | Compute a numerically stable (population) variance over all elements
{-# INLINABLE variance #-}
variance :: (Monad m, Fractional a) => Fold m a a
variance = Fold step (return begin) (return . done)
  where
    begin = Pair3' 0 0 0

    step (Pair3' n mean_ m2) x = return $ Pair3' n' mean' m2'
      where
        n'     = n + 1
        mean'  = (n * mean_ + x) / (n + 1)
        delta  = x - mean_
        m2'    = m2 + delta * delta * n / (n + 1)

    done (Pair3' n _ m2) = m2 / n

-- | Compute a numerically stable (population) standard deviation over all
-- elements
{-# INLINABLE stdDev #-}
stdDev :: (Monad m, Floating a) => Fold m a a
stdDev = sqrt variance

------------------------------------------------------------------------------
-- To Summary (Maybe)
------------------------------------------------------------------------------

-- | Computes the maximum element with respect to the given comparison function
{-# INLINABLE maximumBy #-}
maximumBy :: Monad m => (a -> a -> Ordering) -> Fold m a (Maybe a)
maximumBy cmp = _Fold1 max'
  where
    max' x y = case cmp x y of
        GT -> x
        _  -> y

-- | Computes the maximum element
{-# INLINABLE maximum #-}
maximum :: (Monad m, Ord a) => Fold m a (Maybe a)
maximum = _Fold1 max

-- | Computes the minimum element with respect to the given comparison function
{-# INLINABLE minimumBy #-}
minimumBy :: Monad m => (a -> a -> Ordering) -> Fold m a (Maybe a)
minimumBy cmp = _Fold1 min'
  where
    min' x y = case cmp x y of
        GT -> y
        _  -> x

-- | Computes the minimum element
{-# INLINABLE minimum #-}
minimum :: (Monad m, Ord a) => Fold m a (Maybe a)
minimum = _Fold1 min

------------------------------------------------------------------------------
-- To Containers
------------------------------------------------------------------------------

-- XXX perhaps we should not expose the list APIs as it could be problematic
-- for large lists. We should use a 'Store' type (growable array) instead.
--
-- | Folds the input to a list. This could create performance issues if you
-- are folding large lists. Use 'toArray' instead in that case.

-- id . (x1 :) . (x2 :) . (x3 :) . ... . (xn :) $ []
{-# INLINABLE toList #-}
toList :: Monad m => Fold m a [a]
toList = Fold (\f x -> return $ f . (x :))
              (return id)
              (return . ($ []))

{-# INLINABLE toStream #-}
toStream :: (IsStream t, Monad m) => Fold m a (t m a)
toStream = Fold (\f x -> return $ f . (x `K.cons`))
                (return id)
                (return . ($ K.nil))

-- | Folds the input to a list in the reverse order of the input.  This could
-- create performance issues if you are folding large lists. Use toRevArray
-- instead in that case.

--  xn : ... : x2 : x1 : []
{-# INLINABLE toRevList #-}
toRevList :: Monad m => Fold m a [a]
toRevList = Fold (\xs x -> return $ x:xs) (return []) return

--  XXX use SPEC
--  XXX Make it total, by handling the exception
--  | @toArrayN limit@ folds the input to a single chunk 'Array' of maximum
--  size @limit@. If the input exceeds the limit an error is thrown.
{-# INLINE toArrayN #-}
toArrayN :: forall m a. (Monad m, Storable a) => Int -> Fold m a (Array a)
toArrayN limit = Fold step begin done

    where

    -- XXX use unsafePerformIO instead?
    begin = return $! unsafeDupablePerformIO $ unsafeNew limit
    step v x =
        let !v1 = unsafeDangerousPerformIO (unsafeAppend v x)
        in return v1
    -- XXX resize the array
    done = return

-- Fold to an unlimited vector size. The vector may be created as a tree of
-- vectors. We need to throw an exception if we are getting out of memory.
-- {-# INLINE toArray #-}
-- toArray :: forall m a. (Monad m, Storable a) => Fold m a (Array a)
-- toArray = Fold step begin done

------------------------------------------------------------------------------
-- Grouping/Splitting
------------------------------------------------------------------------------

-- In the bottom up case, we first split and then keep merging, the final
-- solution arrives when we are done merging all of them. In the top down case,
-- we do the work to split and do the same to the two halves.  Finally, the
-- solution is complete when we are done splitting to the bottom.  In other
-- words in one case work is done during the split, in the other case work is
-- done during the merge.
--
-- The first argument of grouping/splitting combinators is a continuation fold
-- that is applied to the grouped output. If we curry the functions with toList
-- fold we can get the combinators that are equivalent to the list combinators.
--
-- inits = FL.toScan
-- tails = FR.toScan

------------------------------------------------------------------------------
-- Grouping without looking at elements
------------------------------------------------------------------------------
--
------------------------------------------------------------------------------
-- Binary APIs
------------------------------------------------------------------------------
--

-- | Split the input stream into two groups at index @n@, the first group
-- consisting of elements from index @0@ to index @n - 1@ i.e. the stream
-- prefix of length @n@ and the second group consisting of the rest of the
-- stream.
--
{-# INLINE splitAt #-}
splitAt
    :: Monad m
    => Int
    -> Fold m a b
    -> Fold m a c
    -> Fold m a (b, c)
splitAt n (Fold stepL initL doneL) (Fold stepR initR doneR) = Fold step init done
    where
        step (index,v1,v2) input = do
            if index > 0 then stepL v1 input >>= (\a -> return (index-1,a,v2))
                         else stepR v2 input >>= (\b -> return (index-1,v1,b))
        init  = (,,) <$> return n <*> initL <*> initR
        done (_,a,b) = (,) <$> doneL a <*> doneR b

------------------------------------------------------------------------------
-- N-ary APIs
------------------------------------------------------------------------------
--
-- Most general APIs for time as well as positional dimensions.
--
-- Block wait for minimum of tmin or nmin, whichever is minimum and collect a
-- maximum of tmax or nmax, whichever is maximum. After the minimum return if
-- would block, collect up to max if does not block.
--
-- foldIntervalsOrGroupsInRange tmin tmax nmin nmax =
-- foldGroupsInRange nmin nmax = foldIntervalsOrGroupsInRange maxBound 0 nmin nmax

-- groupsOf n = foldGroupsInRange n n
-- XXX implement this using grouped, and compare performance.
-- groupsOf' (fold in chunks of sizes provided by a stream/generator func)

-- | Group the input stream into groups of @n@ elements each and then fold each
-- group using the provided fold function.
--
-- >> S.toList $ FL.groupsOf 2 FL.sum (S.enumerateFromTo 1 10)
-- > [3,7,11,15,19]
--
-- @since 0.7.0
{-# INLINE groupsOf #-}
groupsOf
    :: (IsStream t, Monad m)
    => Int -> Fold m a b -> t m a -> t m b
groupsOf n f m = D.fromStreamD $ D.groupsOf n f (D.toStreamD m)

------------------------------------------------------------------------------
-- Element Aware APIs
------------------------------------------------------------------------------
--
------------------------------------------------------------------------------
-- Binary APIs
------------------------------------------------------------------------------

-- | Break the input stream of type (a,Bool) into two groups, the first group
-- takes input as long as the boolean is True, the second group takes the rest
-- of the input.
--
-- This is the most general spanning combinator, all others can be implemented
-- in terms of this.
--
{-# INLINE spanned #-}
spanned
    :: Monad m
    => Fold m a b
    -> Fold m a c
    -> Fold m (a, Bool) (b, c)
spanned (Fold stepL initL doneL) (Fold stepR initR doneR) = Fold step init done
    where
        step (x1,x2,xbool) (input,ibool) = do
            if ibool && xbool
               then stepL x1 input >>= (\a -> return (a,x2,ibool))
               else stepR x2 input >>= (\b -> return (x1,b,ibool))

        init = (,,) <$> initL <*> initR <*> return True

        done (a,b,_) = (,) <$> doneL a <*> doneR b

-- | Break the input stream into two groups, the first group takes the input as
-- long as the predicate applied to the first element of the stream and next
-- input element holds 'True', the second group takes the rest of the input.
{-# INLINE spanBy #-}
spanBy
    :: Monad m
    => (a -> a -> Bool)
    -> Fold m a b
    -> Fold m a c
    -> Fold m a (b, c)
spanBy cmp (Fold stepL initL doneL) (Fold stepR initR doneR) = Fold step init done
    where
        step (a,b,(Just frst)) input = do
            if cmp input frst
               then stepL a input >>= (\a' -> return (a',b,(Just frst)))
               else stepR b input >>= (\b' -> return (a,b',(Just frst)))
        step (a,b,Nothing) input = do
            stepL a input >>= (\a' -> return (a',b,(Just input)))

        init = (,,) <$> initL <*> initR <*> return Nothing

        done (a,b,_) = (,) <$> doneL a <*> doneR b


-- |
-- > span p = spanBy (\_ x -> p x)
--
-- Break the input stream into two groups, the first group takes the input as
-- long as the predicate is 'True', the second group takes the rest of the
-- input.
{-# INLINE span #-}
span
    :: Monad m
    => (a -> Bool)
    -> Fold m a b
    -> Fold m a c
    -> Fold m a (b, c)
span p = spanBy (\_ x -> p x)

-- |
-- > break p = span (not . p)
--
-- Break the input stream into two groups, the first group takes the input as
-- long as the predicate is 'False', the second group takes the rest of the
-- input.
{-# INLINE break #-}
break
    :: Monad m
    => (a -> Bool)
    -> Fold m a b
    -> Fold m a c
    -> Fold m a (b, c)
break p = span (not . p)

-- | Like 'spanBy' but applies the predicate in a rolling fashion i.e.
-- predicate is applied to the previous and the next input elements.
{-# INLINE spanRollingBy #-}
spanRollingBy
    :: Monad m
    => (a -> a -> Bool)
    -> Fold m a b
    -> Fold m a c
    -> Fold m a (b, c)
spanRollingBy cmp (Fold stepL initL doneL) (Fold stepR initR doneR) = Fold step init done
    where
        {-# INLINE_LATE step #-}
        step (a,b,(Just frst)) input = do
            if cmp input frst
               then stepL a input >>= (\a' -> return (a',b,(Just input)))
               else stepR b input >>= (\b' -> return (a,b',(Just input)))
        step (a,b,Nothing) input = do
            stepL a input >>= (\a' -> return (a',b,(Just input)))

        init = (,,) <$> initL <*> initR <*> return Nothing

        done (a,b,_) = (,) <$> doneL a <*> doneR b
------------------------------------------------------------------------------
-- N-ary APIs
------------------------------------------------------------------------------
--
-- The "grouped" combinator uses a simple Bool value to mark the start of a new
-- group. This is ok for stream processing where we do not need to know the
-- delimiter. In a delimited stream the splitter can mark the group elements
-- with a "Right a" value and the delimiter sequence with a "Left (Array a)".
-- This will allow for a general processing, where sometimes we may want to
-- keep the delimiters and sometimes we may want to drop the delimiters. Note
-- that this design allows for only a finite length delimiter.

-- However, we cannot represent overlapping parse using this structure. For
-- overlapping parses we can perhaps use an offset value as well. Just like we
-- can process overlapping time windows using different folds can we process
-- overlapping values using different folds? its like different ways of parsing
-- the stream and using different folds for different parse choices.
--
-- data DelimitedOverlapping a = Delimiter a Int | Value a Int

-- We can use the following constructors for a generalised grouping fold. A
-- scan would group the elements, it can potentially buffer the elements and
-- release them as an Array later or just eat them and not release them at all.
-- s is the internal state of the scan. This way we can implement all kind of
-- splitting, with or without the delimiter, using a scan and the grouped
-- combinator.
--
-- - Yield s (Array a)  -- Yield buffered elements. The array could be empty,
--                      -- single or many elements.
-- - Split s (Array a)  -- Close the previous group and start next group with
--                      -- the new element.
--
-- XXX should we use a strict pair?
--
-- | The splitter returns True if the current element is the last element of
-- the group, otherwise returns false.
{-# INLINE grouped #-}
grouped
    :: (IsStream t, Monad m)
    => Fold m a b
    -> t m (a, Bool)
    -> t m b
grouped f m = D.fromStreamD $ D.grouped f (D.toStreamD m)

-- | Apply a predicate to each new element in the input stream and the first
-- element of the current group. The new element is considered part of the
-- current group if the predicate succeeds otherwise a new group starts.
--
-- >>> S.toList $ FL.groupsBy (==) FL.toList $ S.fromList [1,1,2,2]
-- > [[1,1],[2,2]]
--
{-# INLINE groupsBy #-}
groupsBy
    :: (IsStream t, Monad m)
    => (a -> a -> Bool)
    -> Fold m a b
    -> t m a
    -> t m b
groupsBy cmp f m = D.fromStreamD $ D.groupsBy cmp f (D.toStreamD m)

-- | Apply a predicate to each new element in the input stream and the last
-- element of the current group. In other words, perform a rolling comparison
-- between two successive elements in the stream. The new element is considered
-- part of the current group if the predicate succeeds otherwise a new group
-- starts.
{-# INLINE groupsRollingBy #-}
groupsRollingBy
    :: (IsStream t, Monad m)
    => (a -> a -> Bool)
    -> Fold m a b
    -> t m a
    -> t m b
groupsRollingBy cmp f m = D.fromStreamD $ D.groupsRollingBy cmp f (D.toStreamD m)

-- |
-- > groups = groupsBy (==)
--
-- >>> S.toList $ FL.groups FL.toList $ S.fromList [1,1,2,2]
-- > [[1,1],[2,2]]
--
{-# INLINE groups #-}
groups :: (IsStream t, Monad m, Eq a) => Fold m a b -> t m a -> t m b
groups = groupsBy (==)

------------------------------------------------------------------------------
-- Binary splitting on a separator
------------------------------------------------------------------------------

{-# INLINE breakOn #-}
breakOn :: Monad m => Array a -> Fold m a b -> Fold m a c -> Fold m a (b,c)
breakOn pat f m = undefined

------------------------------------------------------------------------------
-- N-ary split on a predicate
------------------------------------------------------------------------------

-- TODO: Use a Splitter configuration similar to the "split" package to make it
-- possible to express all splitting combinations. In general, we can have
-- infix/suffix/prefix/condensing of separators, dropping both leading/trailing
-- separators. We can have a single split operation taking the splitter config
-- as argument.

-- | Split a stream on separator elements determined by a predicate, dropping
-- the separator.  Separators are not considered part of stream segments on
-- either side of it instead they are treated as infixed between two stream
-- segments. For example, with @.@ as separator, @"a.b.c"@ would be parsed as
-- @["a","b","c"]@. When @.@ is in leading or trailing position it is still
-- considered as infixed, treating the first or the last segment as empty.  For
-- example, @".a."@ would be parsed as @["","a",""]@.  This operation is
-- opposite of 'intercalate'.
--
-- Let's use the following definition for illustration:
--
-- > splitBy_ p xs = S.toList $ FL.splitBy p (FL.toList) (S.fromList xs)
--
-- >>> splitBy_ (== '.') ""
-- [""]
--
-- >>> splitBy_ (== '.') "."
-- ["",""]
--
-- >>> splitBy_ (== '.') ".a"
-- > ["","a"]
--
-- >>> splitBy_ (== '.') "a."
-- > ["a",""]
--
-- >>> splitBy_ (== '.') "a.b"
-- > ["a","b"]
--
-- >>> splitBy_ (== '.') "a..b"
-- > ["a","","b"]
--
{-# INLINE splitBy #-}
splitBy
    :: (IsStream t, Monad m)
    => (a -> Bool) -> Fold m a b -> t m a -> t m b
splitBy predicate f m =
    D.fromStreamD $ D.splitBy predicate f (D.toStreamD m)

-- | Like 'splitBy' but the separator is treated as part of the previous
-- stream segment (suffix).  Therefore, when the separator is in trailing
-- position, no empty segment is considered to follow it. For example, @"a.b."@
-- would be parsed as @["a","b"]@ instead of @["a","b",""]@ as in the case of
-- 'splitBy'.
--
-- > splitSuffixBy_ p xs = S.toList $ FL.splitSuffixBy p (FL.toList) (S.fromList xs)
--
-- >>> splitSuffixBy_ (== '.') ""
-- []
--
-- >>> splitSuffixBy_ (== '.') "."
-- [""]
--
-- >>> splitSuffixBy_ (== '.') "a"
-- ["a"]
--
-- >>> splitSuffixBy_ (== '.') ".a"
-- > ["","a"]
--
-- >>> splitSuffixBy_ (== '.') "a."
-- > ["a"]
--
-- >>> splitSuffixBy_ (== '.') "a.b"
-- > ["a","b"]
--
-- >>> splitSuffixBy_ (== '.') "a.b."
-- > ["a","b"]
--
-- >>> splitSuffixBy_ (== '.') "a..b.."
-- > ["a","","b",""]
--
-- > lines = splitSuffixBy (== '\n')
--
{-# INLINE splitSuffixBy #-}
splitSuffixBy
    :: (IsStream t, Monad m)
    => (a -> Bool) -> Fold m a b -> t m a -> t m b
splitSuffixBy predicate f m =
    D.fromStreamD $ D.splitSuffixBy predicate f (D.toStreamD m)

-- | Like 'splitBy' but ignores repeated separators or separators in leading
-- or trailing position. Therefore, @"..a..b.."@ would be parsed as
-- @["a","b"]@.  In other words, it treats the input like words separated by
-- whitespace elements determined by the predicate.
--
-- > wordsBy' p xs = S.toList $ FL.wordsBy p (FL.toList) (S.fromList xs)
--
-- >>> wordsBy' (== ',') ""
-- > []
--
-- >>> wordsBy' (== ',') ","
-- > []
--
-- >>> wordsBy' (== ',') ",a,,b,"
-- > ["a","b"]
--
-- > words = wordsBy isSpace
--
{-# INLINE wordsBy #-}
wordsBy
    :: (IsStream t, Monad m)
    => (a -> Bool) -> Fold m a b -> t m a -> t m b
wordsBy predicate f m =
    D.fromStreamD $ D.wordsBy predicate f (D.toStreamD m)

-- XXX we should express this using the Splitter config.
--
-- We can get splitSuffixBy' by appending the suffix to the output segments
-- produced by splitSuffixBy. However, it may add an additional suffix if the last
-- fragment did not have a suffix in the first place.

-- | Like 'splitSuffixBy' but keeps the suffix in the splits.
--
-- > splitSuffixBy'_ p xs = S.toList $ FL.splitSuffixBy' p (FL.toList) (S.fromList xs)
--
-- >>> splitSuffixBy'_ (== '.') ""
-- []
--
-- >>> splitSuffixBy'_ (== '.') "."
-- ["."]
--
-- >>> splitSuffixBy'_ (== '.') "a"
-- ["a"]
--
-- >>> splitSuffixBy'_ (== '.') ".a"
-- > [".","a"]
--
-- >>> splitSuffixBy'_ (== '.') "a."
-- > ["a."]
--
-- >>> splitSuffixBy'_ (== '.') "a.b"
-- > ["a.","b"]
--
-- >>> splitSuffixBy'_ (== '.') "a.b."
-- > ["a.","b."]
--
-- >>> splitSuffixBy'_ (== '.') "a..b.."
-- > ["a.",".","b.","."]
--
{-# INLINE _splitSuffixBy' #-}
_splitSuffixBy'
    :: (IsStream t, Monad m)
    => (a -> Bool) -> Fold m a b -> t m a -> t m b
_splitSuffixBy' predicate f m = grouped f (S.map (\a -> (a, predicate a)) m)

------------------------------------------------------------------------------
-- Split on a delimiter
------------------------------------------------------------------------------

-- Int list examples for splitOn:
--
-- >>> splitList [] [1,2,3,3,4]
-- > [[1],[2],[3],[3],[4]]
--
-- >>> splitList [5] [1,2,3,3,4]
-- > [[1,2,3,3,4]]
--
-- >>> splitList [1] [1,2,3,3,4]
-- > [[],[2,3,3,4]]
--
-- >>> splitList [4] [1,2,3,3,4]
-- > [[1,2,3,3],[]]
--
-- >>> splitList [2] [1,2,3,3,4]
-- > [[1],[3,3,4]]
--
-- >>> splitList [3] [1,2,3,3,4]
-- > [[1,2],[],[4]]
--
-- >>> splitList [3,3] [1,2,3,3,4]
-- > [[1,2],[4]]
--
-- >>> splitList [1,2,3,3,4] [1,2,3,3,4]
-- > [[],[]]

-- | Split the stream on both sides of a separator sequence, dropping the
-- separator.
--
-- For illustration, let's define a function that operates on pure lists:
--
-- @
-- splitOn_ pat xs = S.toList $ FL.splitOn (A.fromList pat) (FL.toList) (S.fromList xs)
-- @
--
-- >>> splitOn_ "" "hello"
-- > ["h","e","l","l","o"]
--
-- >>> splitOn_ "hello" ""
-- > [""]
--
-- >>> splitOn_ "hello" "hello"
-- > ["",""]
--
-- >>> splitOn_ "x" "hello"
-- > ["hello"]
--
-- >>> splitOn_ "h" "hello"
-- > ["","ello"]
--
-- >>> splitOn_ "o" "hello"
-- > ["hell",""]
--
-- >>> splitOn_ "e" "hello"
-- > ["h","llo"]
--
-- >>> splitOn_ "l" "hello"
-- > ["he","","o"]
--
-- >>> splitOn_ "ll" "hello"
-- > ["he","o"]
--
-- 'splitOn' is an inverse of 'intercalate'. The following law always holds:
--
-- > intercalate . splitOn == id
--
-- The following law holds when the separator is non-empty and contains none of
-- the elements present in the input lists:
--
-- > splitOn . intercalate == id
--
-- The following law always holds:
--
-- > concat . splitOn . intercalate == concat
--
{-# INLINE splitOn #-}
splitOn
    :: (IsStream t, Monad m, Storable a, Enum a, Eq a)
    => Array a -> Fold m a b -> t m a -> t m b
splitOn patt f m = D.fromStreamD $ D.splitOn patt f (D.toStreamD m)

-- This can be implemented easily using Rabin Karp
-- | Split on any one of the given patterns.
{-# INLINE splitOnAny #-}
splitOnAny
    :: (IsStream t, Monad m, Storable a, Integral a)
    => [Array a] -> Fold m a b -> t m a -> t m b
splitOnAny subseq f m = undefined -- D.fromStreamD $ D.splitOnAny f subseq (D.toStreamD m)

-- | Like 'splitSuffixBy' but the separator is a sequence of elements, instead
-- of a predicate for a single element.
--
-- > splitSuffixOn_ pat xs = S.toList $ FL.splitSuffixOn (A.fromList pat) (FL.toList) (S.fromList xs)
--
-- >>> splitSuffixOn_ "." ""
-- [""]
--
-- >>> splitSuffixOn_ "." "."
-- [""]
--
-- >>> splitSuffixOn_ "." "a"
-- ["a"]
--
-- >>> splitSuffixOn_ "." ".a"
-- > ["","a"]
--
-- >>> splitSuffixOn_ "." "a."
-- > ["a"]
--
-- >>> splitSuffixOn_ "." "a.b"
-- > ["a","b"]
--
-- >>> splitSuffixOn_ "." "a.b."
-- > ["a","b"]
--
-- >>> splitSuffixOn_ "." "a..b.."
-- > ["a","","b",""]
--
-- > lines = splitSuffixOn "\n"
--
{-# INLINE splitSuffixOn #-}
splitSuffixOn
    :: (IsStream t, Monad m, Storable a, Enum a, Eq a)
    => Array a -> Fold m a b -> t m a -> t m b
splitSuffixOn patt f m =
    D.fromStreamD $ D.splitSuffixOn False patt f (D.toStreamD m)

-- | Like 'splitOn' but drops any empty splits.
--
{-# INLINE wordsOn #-}
wordsOn
    :: (IsStream t, Monad m, Storable a, Eq a)
    => Array a -> Fold m a b -> t m a -> t m b
wordsOn subseq f m = undefined -- D.fromStreamD $ D.wordsOn f subseq (D.toStreamD m)

-- | Like 'splitOn' but splits the separator as well, as an infix token.
--
-- > splitOn'_ pat xs = S.toList $ FL.splitOn' (A.fromList pat) (FL.toList) (S.fromList xs)
--
-- >>> splitOn'_ "" "hello"
-- > ["h","","e","","l","","l","","o"]
--
-- >>> splitOn'_ "hello" ""
-- > [""]
--
-- >>> splitOn'_ "hello" "hello"
-- > ["","hello",""]
--
-- >>> splitOn'_ "x" "hello"
-- > ["hello"]
--
-- >>> splitOn'_ "h" "hello"
-- > ["","h","ello"]
--
-- >>> splitOn'_ "o" "hello"
-- > ["hell","o",""]
--
-- >>> splitOn'_ "e" "hello"
-- > ["h","e","llo"]
--
-- >>> splitOn'_ "l" "hello"
-- > ["he","l","","l","o"]
--
-- >>> splitOn'_ "ll" "hello"
-- > ["he","ll","o"]
--
{-# INLINE splitOn' #-}
splitOn'
    :: (IsStream t, MonadAsync m, Storable a, Enum a, Eq a)
    => Array a -> Fold m a b -> t m a -> t m b
splitOn' patt f m = S.intersperseM
    (foldl f (P.fromArray patt)) $ splitOn patt f m

-- | Like 'splitSuffixOn' but keeps the suffix intact in the splits.
--
-- > splitSuffixOn'_ pat xs = S.toList $ FL.splitSuffixOn' (A.fromList pat) (FL.toList) (S.fromList xs)
--
-- >>> splitSuffixOn'_ "." ""
-- [""]
--
-- >>> splitSuffixOn'_ "." "."
-- ["."]
--
-- >>> splitSuffixOn'_ "." "a"
-- ["a"]
--
-- >>> splitSuffixOn'_ "." ".a"
-- > [".","a"]
--
-- >>> splitSuffixOn'_ "." "a."
-- > ["a."]
--
-- >>> splitSuffixOn'_ "." "a.b"
-- > ["a.","b"]
--
-- >>> splitSuffixOn'_ "." "a.b."
-- > ["a.","b."]
--
-- >>> splitSuffixOn'_ "." "a..b.."
-- > ["a.",".","b.","."]
--
{-# INLINE splitSuffixOn' #-}
splitSuffixOn'
    :: (IsStream t, Monad m, Storable a, Enum a, Eq a)
    => Array a -> Fold m a b -> t m a -> t m b
splitSuffixOn' patt f m =
    D.fromStreamD $ D.splitSuffixOn True patt f (D.toStreamD m)

-- This can be implemented easily using Rabin Karp
-- | Split post any one of the given patterns.
{-# INLINE splitSuffixOnAny #-}
splitSuffixOnAny
    :: (IsStream t, Monad m, Storable a, Integral a)
    => [Array a] -> Fold m a b -> t m a -> t m b
splitSuffixOnAny subseq f m = undefined -- D.fromStreamD $ D.splitPostAny f subseq (D.toStreamD m)

------------------------------------------------------------------------------
-- Grouped by order
------------------------------------------------------------------------------

{-
-- Buffer until the next element in sequence arrives. The function argument
-- determines the difference in sequence numbers. This could be useful in
-- implementing sequenced streams, for example, TCP reassembly.
{-# INLINE foldOrderedBy #-}
foldOrderedBy
    :: (IsStream t, Monad m)
    => (forall n. Monad n => Fold n a b)
    -> (a -> a -> Int)
    -> t m a
    -> t m b
foldOrderedBy = undefined
-}

-- XXX put time related functions in Streamly.Time?
--
------------------------------------------------------------------------------
-- Grouping by time
------------------------------------------------------------------------------
--
-- splitAtInterval
-- foldIntervalsInRange tmin tmax = foldIntervalsOrGroupsInRange tmin tmax maxBound 0
-- foldIntervalsOf n = foldIntervalsInRange n n
-- chunksOfInterval
--
------------------------------------------------------------------------------
-- Grouping looking at timestamps
------------------------------------------------------------------------------
--
-- timestamp the elements in the stream. We can then group by timestamp
-- intervals and fold. This is just a special case of a general groupBy.
-- This can be useful in folding based on the generation times rather than
-- arrival times.
--
-- foldTSIntervalsOrGroupsInRange tmin tmax nmin nmax =

------------------------------------------------------------------------------
-- Splitters
------------------------------------------------------------------------------
--
{-
-- XXX this is the job of a splitter. The splitter can buffer until the
-- splitting pattern has matched or we know it won't match and then emit the
-- stream.
--
-- Like grouped but the grouping fold returns the stream elements instead
-- of returning a 'Bool' value. A 'Right' value means the group is not complete
-- yet, a 'Left' value means this is the final chunk of the group. This allows
-- the fold to eat, replace or add elements to the input, but still emit the
-- output as soon as possible without unnecessary buffering (compare with
-- groupByFoldBuffered). For example, we can match on a pattern but emit groups
-- without the pattern.
groupsByFoldModifying
    :: (IsStream t, MonadIO m, Storable a, Eq a)
    => (forall n. MonadIO n => Fold n a b)
    -> (forall n. Fold n a (Either (Array a) (Array a)))
    -> t m a
    -> t m b
-}

newline :: IsStream t => t m Char -> t m (Char,Bool)
newline m = S.foldrS (\x xs ->
    if x == '\n'
    then (x,True) `K.cons` xs
    else (x,False) `K.cons` xs) K.nil m
