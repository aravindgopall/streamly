{-# LANGUAGE CPP #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MagicHash #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE UnboxedTuples #-}

#include "inline.hs"

-- |
-- Module      : Streamly.Network.Socket
-- Copyright   : (c) 2018 Harendra Kumar
--
-- License     : BSD3
-- Maintainer  : harendra.kumar@gmail.com
-- Stability   : experimental
-- Portability : GHC
--
-- Read and write streams and arrays to and from files. File IO APIs are quite
-- similar to "Streamly.Mem.Array" read write APIs. In that regard, arrays can
-- be considered as in-memory files or files can be considered as on-disk
-- arrays.  IO APIs are divided into two categories, sequential streaming IO
-- APIs and random access IO APIs.  Control over the file reading and writing
-- behavior in terms of buffering, encoding, decoding is in the hands of the
-- programmer, the 'TextEncoding', 'NewLineMode', and 'Buffering' options of
-- the underlying handle provided by GHC are not needed and ignored.
--
-- > import qualified Streamly.Network.Socket as SK
--

module Streamly.Network.Socket
    (
    -- * Streaming Network IO
    -- | Stream data to or from a file or device sequentially.  When reading,
    -- the stream is lazy and generated on-demand as the consumer consumes it.
    -- Read IO requests to the IO device are performed in chunks limited to a
    -- maximum size of 32KiB, this is referred to as @defaultChunkSize@ in the
    -- documentation. One IO request may or may not read the full
    -- chunk. If the whole stream is not consumed, it is possible that we may
    -- read slightly more from the IO device than what the consumer needed.
    -- Unless specified otherwise in the API, writes are collected into chunks
    -- of @defaultChunkSize@ before they are written to the IO device.

    -- Streaming APIs work for all kind of devices, seekable or non-seekable;
    -- including disks, files, memory devices, terminals, pipes, sockets and
    -- fifos. While random access APIs work only for files or devices that have
    -- random access or seek capability for example disks, memory devices.
    -- Devices like terminals, pipes, sockets and fifos do not have random
    -- access capability.

    -- TODO network address based APIs
    -- , readAddr  -- fromAddr?
    -- , writeAddr -- toAddr

    -- ** Listen for Connections
       TCPServerOpts(..)
     , serveTCP

    -- ** Read a stream from a connection
      , read
    -- , readUtf8
    -- , readLines
    -- , readFrames
    -- , readByChunks

    -- -- * Array Read
    -- , readArrayUpto
    -- , readArrayOf

    -- , readArraysUpto
    -- , readArraysOf
    , readArrays

    -- ** Write a stream to a connection
    , write
    -- , writeUtf8
    -- , writeUtf8ByLines
    -- , writeByFrames
    , writeByChunks

    -- -- * Array Write
    , writeArray
    , writeArrays
    )
where

import Control.Concurrent (threadWaitWrite, rtsSupportsBoundThreads)
import Control.Monad.IO.Class (MonadIO(..))
import Control.Monad (when)
import Data.Word (Word8)
import Foreign.ForeignPtr (withForeignPtr)
import Foreign.ForeignPtr.Unsafe (unsafeForeignPtrToPtr)
import Foreign.Ptr (minusPtr, plusPtr, Ptr, castPtr)
import Foreign.Storable (Storable(..))
import GHC.ForeignPtr (mallocPlainForeignPtrBytes)
import Prelude hiding (read)

import Streamly.Mem.Array.Types (Array(..))
import Streamly.Streams.Serial (SerialT)
import Streamly.Streams.StreamK.Type (IsStream, mkStream)
-- import Streamly.Fold (Fold)
-- import Streamly.String (encodeUtf8, decodeUtf8, foldLines)

import qualified Streamly.Mem.Array as A
import qualified Streamly.Mem.Array.Types as A hiding (flattenArrays)
import qualified Streamly.Prelude as S

import Network.Socket hiding (listen)
import qualified Network.Socket as Net
-- import           Network.Socket.ByteString as NBS
import           Streamly (MonadAsync)

-- XXX we will need a concatMapWith parallel to merge all the connections
-- concurrently.
--
-------------------------------------------------------------------------------
-- Listen
-------------------------------------------------------------------------------

data TCPServerOpts = TCPServerOpts
    {
      tcpAddressFamily :: !Family
    , tcpSockOpts      :: ![(SocketOption, Int)]
    , tcpSockAddr      :: !SockAddr
    , tcpListenQ       :: !Int
    }

-- tcpSocketOptions = [(NS.NoDelay,1), (NS.ReuseAddr,1)]
-- bind sock (SockAddrInet port 0)

initListener :: TCPServerOpts -> IO Socket
initListener TCPServerOpts{..} =
  withSocketsDo $ do
    sock <- socket tcpAddressFamily Stream defaultProtocol
    mapM_ (\(opt, val) -> setSocketOption sock opt val) tcpSockOpts
    bind sock tcpSockAddr
    Net.listen sock tcpListenQ
    return sock

{-# INLINE serveTCP #-}
serveTCP :: MonadAsync m => TCPServerOpts -> SerialT m (Socket, SockAddr)
serveTCP opts = S.unfoldrM step Nothing
    where
    step Nothing = do
        listener <- liftIO $ initListener opts
        r <- liftIO $ accept listener
        -- XXX error handling
        return $ Just (r, Just listener)

    step (Just listener) = do
        r <- liftIO $ accept listener
        -- XXX error handling
        return $ Just (r, Just listener)

-------------------------------------------------------------------------------
-- Array IO (Input)
-------------------------------------------------------------------------------

-- | Read a 'ByteArray' from a file handle. If no data is available on the
-- handle it blocks until some data becomes available. If data is available
-- then it immediately returns that data without blocking. It reads a maximum
-- of up to the size requested.
{-# INLINABLE readArrayUpto #-}
readArrayUpto :: Int -> Socket -> IO (Array Word8)
readArrayUpto size h = do
    ptr <- mallocPlainForeignPtrBytes size
    -- ptr <- mallocPlainForeignPtrAlignedBytes size (alignment (undefined :: Word8))
    withForeignPtr ptr $ \p -> do
        n <- recvBuf h p size
        let v = Array
                { aStart = ptr
                , aEnd   = p `plusPtr` n
                , aBound = p `plusPtr` size
                }
        -- XXX shrink only if the diff is significant
        -- A.shrinkToFit v
        return v

-------------------------------------------------------------------------------
-- Array IO (output)
-------------------------------------------------------------------------------

waitWhen0 :: Int -> Socket -> IO ()
waitWhen0 0 s = when rtsSupportsBoundThreads $
    withFdSocket s $ \fd -> threadWaitWrite $ fromIntegral fd
waitWhen0 _ _ = return ()

sendAll :: Socket -> Ptr Word8 -> Int -> IO ()
sendAll _ _ len | len <= 0 = return ()
sendAll s p len = do
    sent <- sendBuf s p len
    waitWhen0 sent s
    -- assert (sent <= len)
    when (sent >= 0) $ sendAll s (p `plusPtr` sent) (len - sent)

-- | Write an Array to a file handle.
--
-- @since 0.7.0
{-# INLINABLE writeArray #-}
writeArray :: Storable a => Socket -> Array a -> IO ()
writeArray _ arr | A.length arr == 0 = return ()
writeArray h Array{..} = withForeignPtr aStart $ \p ->
    sendAll h (castPtr p) aLen
    where
    aLen =
        let p = unsafeForeignPtrToPtr aStart
        in aEnd `minusPtr` p

-------------------------------------------------------------------------------
-- Stream of Arrays IO
-------------------------------------------------------------------------------

-- | @readArraysUpto size h@ reads a stream of arrays from file handle @h@.
-- The maximum size of a single array is limited to @size@.
-- 'fromHandleArraysUpto' ignores the prevailing 'TextEncoding' and 'NewlineMode'
-- on the 'Handle'.
{-# INLINABLE readArraysUpto #-}
readArraysUpto :: (IsStream t, MonadIO m)
    => Int -> Socket -> t m (Array Word8)
readArraysUpto size h = go
  where
    -- XXX use cons/nil instead
    go = mkStream $ \_ yld sng _ -> do
        arr <- liftIO $ readArrayUpto size h
        if A.length arr < size
        then sng arr
        else yld arr go

-- XXX read 'Array a' instead of Word8
--
-- | @readArrays h@ reads a stream of arrays from file handle @h@.
-- The maximum size of a single array is limited to @defaultChunkSize@.
-- 'readArrays' ignores the prevailing 'TextEncoding' and 'NewlineMode'
-- on the 'Handle'.
--
-- @since 0.7.0
{-# INLINE readArrays #-}
readArrays :: (IsStream t, MonadIO m) => Socket -> t m (Array Word8)
readArrays = readArraysUpto A.defaultChunkSize

-------------------------------------------------------------------------------
-- Read File to Stream
-------------------------------------------------------------------------------

-- TODO for concurrent streams implement readahead IO. We can send multiple
-- read requests at the same time. For serial case we can use async IO. We can
-- also control the read throughput in mbps or IOPS.

{-
-- | @readByChunksUpto chunkSize handle@ reads a byte stream from a file
-- handle, reads are performed in chunks of up to @chunkSize@.  The stream ends
-- as soon as EOF is encountered.
--
{-# INLINE readByChunksUpto #-}
readByChunksUpto :: (IsStream t, MonadIO m) => Int -> Handle -> t m Word8
readByChunksUpto chunkSize h = A.flattenArrays $ readArraysUpto chunkSize h
-}

-- TODO
-- read :: (IsStream t, MonadIO m, Storable a) => Handle -> t m a
--
-- > read = 'readByChunks' A.defaultChunkSize
-- | Generate a stream of elements of the given type from a file 'Handle'. The
-- stream ends when EOF is encountered.
--
-- @since 0.7.0
{-# INLINE read #-}
read :: (IsStream t, MonadIO m) => Socket -> t m Word8
read = A.flattenArrays . readArrays

-------------------------------------------------------------------------------
-- Writing
-------------------------------------------------------------------------------

-- | Write a stream of arrays to a handle.
--
-- @since 0.7.0
{-# INLINE writeArrays #-}
writeArrays :: (MonadIO m, Storable a) => Socket -> SerialT m (Array a) -> m ()
writeArrays h m = S.mapM_ (liftIO . writeArray h) m

-- GHC buffer size dEFAULT_FD_BUFFER_SIZE=8192 bytes.
--
-- XXX test this
-- Note that if you use a chunk size less than 8K (GHC's default buffer
-- size) then you are advised to use 'NOBuffering' mode on the 'Handle' in case you
-- do not want buffering to occur at GHC level as well. Same thing applies to
-- writes as well.

-- | Like 'write' but provides control over the write buffer. Output will
-- be written to the IO device as soon as we collect the specified number of
-- input elements.
--
-- @since 0.7.0
{-# INLINE writeByChunks #-}
writeByChunks :: MonadIO m => Int -> Socket -> SerialT m Word8 -> m ()
writeByChunks n h m = writeArrays h $ A.arraysOf n m

-- > write = 'writeByChunks' A.defaultChunkSize
--
-- | Write a byte stream to a file handle. Combines the bytes in chunks of size
-- up to 'A.defaultChunkSize' before writing.  Note that the write behavior
-- depends on the 'IOMode' and the current seek position of the handle.
--
-- @since 0.7.0
{-# INLINE write #-}
write :: MonadIO m => Socket -> SerialT m Word8 -> m ()
write = writeByChunks A.defaultChunkSize

{-
{-# INLINE write #-}
write :: (MonadIO m, Storable a) => Handle -> SerialT m a -> m ()
write = toHandleWith A.defaultChunkSize
-}

-------------------------------------------------------------------------------
-- IO with encoding/decoding Unicode characters
-------------------------------------------------------------------------------

{-
-- |
-- > readUtf8 = decodeUtf8 . read
--
-- Read a UTF8 encoded stream of unicode characters from a file handle.
--
-- @since 0.7.0
{-# INLINE readUtf8 #-}
readUtf8 :: (IsStream t, MonadIO m) => Handle -> t m Char
readUtf8 = decodeUtf8 . read

-- |
-- > writeUtf8 h s = write h $ encodeUtf8 s
--
-- Encode a stream of unicode characters to UTF8 and write it to the given file
-- handle. Default block buffering applies to the writes.
--
-- @since 0.7.0
{-# INLINE writeUtf8 #-}
writeUtf8 :: MonadIO m => Handle -> SerialT m Char -> m ()
writeUtf8 h s = write h $ encodeUtf8 s

-- | Write a stream of unicode characters after encoding to UTF-8 in chunks
-- separated by a linefeed character @'\n'@. If the size of the buffer exceeds
-- @defaultChunkSize@ and a linefeed is not yet found, the buffer is written
-- anyway.  This is similar to writing to a 'Handle' with the 'LineBuffering'
-- option.
--
-- @since 0.7.0
{-# INLINE writeUtf8ByLines #-}
writeUtf8ByLines :: (IsStream t, MonadIO m) => Handle -> t m Char -> m ()
writeUtf8ByLines = undefined

-- | Read UTF-8 lines from a file handle and apply the specified fold to each
-- line. This is similar to reading a 'Handle' with the 'LineBuffering' option.
--
-- @since 0.7.0
{-# INLINE readLines #-}
readLines :: (IsStream t, MonadIO m) => Handle -> Fold m Char b -> t m b
readLines h f = foldLines (readUtf8 h) f

-------------------------------------------------------------------------------
-- Framing on a sequence
-------------------------------------------------------------------------------

-- | Read a stream from a file handle and split it into frames delimited by
-- the specified sequence of elements. The supplied fold is applied on each
-- frame.
--
-- @since 0.7.0
{-# INLINE readFrames #-}
readFrames :: (IsStream t, MonadIO m, Storable a)
    => Array a -> Handle -> Fold m a b -> t m b
readFrames = undefined -- foldFrames . read

-- | Write a stream to the given file handle buffering up to frames separated
-- by the given sequence or up to a maximum of @defaultChunkSize@.
--
-- @since 0.7.0
{-# INLINE writeByFrames #-}
writeByFrames :: (IsStream t, MonadIO m, Storable a)
    => Array a -> Handle -> t m a -> m ()
writeByFrames = undefined
-}
