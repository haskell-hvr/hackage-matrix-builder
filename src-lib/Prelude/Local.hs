{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE PolyKinds             #-}
{-# LANGUAGE RankNTypes            #-}

{-# OPTIONS_GHC -Wno-orphans #-}

-- |
-- Copyright: © 2018 Herbert Valerio Riedel
-- SPDX-License-Identifier: GPL-3.0-or-later
--
module Prelude.Local
    ( T.Text
    , FromJSON(..)
    , ToJSON(..)

    , C.simpleParse, C.display

    , POSIXTime
    , UTCTime
    , NominalDiffTime
    , getCurrentTime
    , getPOSIXTime
    , posixSecondsToUTCTime
    , utcTimeToPOSIXSeconds
    , diffUTCTime

    , readMaybe
    , isDigit
    , coerce

    , InputStream, OutputStream

    , BS.ByteString
    , SBS.ShortByteString
    , Async
    , Set
    , Map
    , IntMap
    , Vector

    , NonEmpty(..)
    , UUID.UUID

    -- * Locally defined helpers
    , toposort
    , firstJustM
    , whileM_

    , tshow
    , tdisplay

    -- ** UUID helpers
    , uuidHash
    , uuidNil

    -- * Whole module re-exports
    , module Control.Concurrent.MVar
    , module Control.Monad
    , module Control.DeepSeq
    , module Control.Exception
    , module Control.Monad.IO.Class
    , module Data.Bifunctor
    , module Data.List
    , module Data.Maybe
    , module Data.Proxy
    , module Data.Semigroup
    , module System.Directory
    , module System.Environment
    , module System.Exit
    , module System.FilePath
    , module Data.Hashable
    , module Data.Word
    , module Data.Int
    , module Control.Lens
    , module Data.Foldable
    , module Data.Ord

    , module Prelude
    ) where

import           Control.Concurrent.Async
import           Control.Concurrent.MVar
import           Control.DeepSeq
import           Control.Exception        hiding (Handler)
import           Control.Lens             hiding ((<.>))
import           Control.Monad
import           Control.Monad.IO.Class
import qualified Crypto.Hash.SHA256       as SHA256
import           Data.Aeson
import           Data.Bifunctor
import           Data.Bits
import qualified Data.ByteString          as BS
import qualified Data.ByteString.Lazy     as BSL
import qualified Data.ByteString.Short    as SBS
import           Data.Char                (isDigit)
import           Data.Coerce              (coerce)
import           Data.Foldable
import qualified Data.Graph               as G
import           Data.Hashable
import           Data.Int
import           Data.IntMap              (IntMap)
import           Data.List                hiding (head, init, last, tail,
                                           uncons)
import           Data.List.NonEmpty       (NonEmpty (..))
import           Data.Map                 (Map)
import qualified Data.Map.Strict          as Map
import           Data.Maybe
import           Data.Monoid
import           Data.Ord
import           Data.Proxy
import           Data.Semigroup
import           Data.Set                 (Set)
import qualified Data.Set                 as Set
import qualified Data.Text                as T
import           Data.Time.Clock          (NominalDiffTime, UTCTime,
                                           diffUTCTime, getCurrentTime)
import           Data.Time.Clock.POSIX    (POSIXTime, getPOSIXTime,
                                           posixSecondsToUTCTime,
                                           utcTimeToPOSIXSeconds)
import qualified Data.UUID.Types          as UUID
import           Data.Vector              (Vector)
import           Data.Word
import qualified Distribution.Text        as C
import qualified Distribution.Pretty      as C
import           Prelude                  hiding (print, putStr, putStrLn,
                                           uncons)
import           System.Directory
import           System.Environment
import           System.Exit
import           System.FilePath
import           System.IO.Streams        (InputStream, OutputStream)
import           Text.Read


uuidNil :: UUID.UUID
uuidNil = UUID.nil

uuidHash :: BS.ByteString -> UUID.UUID
uuidHash buf = UUID.fromWords (x1 `xor` y1) (x2 `xor` y2) (x3 `xor` y3) (x4 `xor` y4)
  where
    (xs,ys) = BS.splitAt 16 $ SHA256.hash buf
    Just (x1,x2,x3,x4) = UUID.toWords <$> UUID.fromByteString (BSL.fromStrict xs)
    Just (y1,y2,y3,y4) = UUID.toWords <$> UUID.fromByteString (BSL.fromStrict ys)



{-
-- quickndirty & broken  topological sort
toposort :: Ord a => Map a (Set a) -> [a]
toposort m = uniq mempty $ reverse $ go (Map.keysSet m)
  where
    go xs = concatMap go1 xs
    go1 x = x : go ys
      where
        Just ys = Map.lookup x m

    uniq _    [] = []
    uniq seen (x:xs)
      | Set.member x seen = uniq seen xs
      | otherwise         = x : uniq (Set.insert x seen) xs
-}

toposort :: Ord a => Map a (Set a) -> [a]
toposort m = reverse . map f . G.topSort $ g
  where
    (g, f) = graphFromMap m

graphFromMap :: Ord a => Map a (Set a) -> (G.Graph, G.Vertex -> a)
graphFromMap m = (g, v2k')
  where
    v2k' v = case v2k v of ((), k, _) -> k
    (g, v2k, _) = G.graphFromEdges [ ((), k, Set.toList v)
                                   | (k,v) <- Map.toList m ]

-- | Perform action until first 'Just' result is encountered (which is
-- returned). Returns 'Nothing' if none could be found.
firstJustM :: (a -> IO (Maybe b)) -> [a] -> IO (Maybe b)
firstJustM act = go
  where
    go [] = pure Nothing
    go (x:xs) = do
        y <- act x
        case y of
          Just _  -> pure y
          Nothing -> go xs


-- | Execute monadic action as long as it returns 'True'
whileM_ :: (Monad m) => m Bool -> m ()
whileM_ p = go
  where
    go = do
        x <- p
        if x then go else pure ()


-- FIXME
instance (Hashable k, Hashable v) => Hashable (Map k v) where
    hashWithSalt s = hashWithSalt s . Map.toList

instance Hashable k => Hashable (Set k ) where
    hashWithSalt s = hashWithSalt s . Set.toAscList


tshow :: Show s => s -> T.Text
tshow = T.pack . show


tdisplay :: C.Pretty s => s -> T.Text
tdisplay = T.pack . C.display
