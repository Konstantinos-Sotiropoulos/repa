
-- | Loading and storing integers directly from/to memory buffers.
module Data.Repa.Scalar.Int
        ( -- * Loading
          loadInt
        , loadInt#
        , loadIntWith#

          -- * Storing
        , storeInt)
where
import Data.Word
import Data.Char
import GHC.Exts
import qualified Data.ByteString.Internal               as BS
import qualified Data.Double.Conversion.ByteString      as DC
import qualified Foreign.ForeignPtr                     as F
import qualified Foreign.Storable                       as F


-- Int --------------------------------------------------------------------------------------------
-- | Load an ASCII `Int` from a foreign buffer,
--   returning the value and number of characters read.
loadInt :: Ptr Word8                    -- ^ Buffer holding digits.
        -> Int                          -- ^ Length of buffer.
        -> IO (Maybe (Int, Int))        -- ^ Int read, and length of digits.
 
loadInt !ptr (I# len)
 = case loadInt# ptr len of
        (# 0#, _, _  #) -> return $ Nothing
        (# _,  n, ix #) -> return $ Just (I# n, I# ix)
{-# INLINE loadInt #-}


-- | Like `loadInt`, but via unboxed types.
loadInt#
        :: Ptr Word8                    -- ^ Buffer holding digits.
        -> Int#                         -- ^ Length of buffer.
        -> (# Int#, Int#, Int# #)       -- ^ Convert success?, value, length read.

loadInt# buf len
 = let peek8 ix
           -- accursed .. may increase sharing of the result value, 
           -- but this isn't a problem here because the result is not
           -- mutable, and will be unboxed by the simplifier anyway.
         = case BS.accursedUnutterablePerformIO (F.peekByteOff buf (I# ix)) of
                (w8 :: Word8) -> case fromIntegral w8 of
                                        I# i    -> i
       {-# INLINE peek8 #-}

   in  loadIntWith# peek8 len
{-# NOINLINE loadInt# #-}


-- | Like `loadInt#`, but use the given function to get characters
--   from the input buffer.
loadIntWith# 
        :: (Int# -> Int#)               -- ^ Function to get a byte from the source.
        -> Int#                         -- ^ Length of buffer
        -> (# Int#, Int#, Int# #)       -- ^ Convert success?, value, length read.

loadIntWith# !get len
 = start 0#
 where
        start !ix
         | 1# <- ix >=# len = (# 0#, 0#, 0# #)
         | otherwise        = sign ix
        {-# INLINE start #-}

        -- Check for explicit sign character,
        -- and encode what it was as an integer.
        sign !ix
         | !s   <- get 0#
         = case chr $ fromIntegral (I# s) of
                '-'     -> loop 1# (ix +# 1#) 0#
                '+'     -> loop 2# (ix +# 1#) 0#
                _       -> loop 0#  ix        0#
        {-# INLINE sign #-}

        loop !neg !ix !n 
         -- We've hit the end of the array.
         | 1# <- ix >=# len   
         = end neg ix n

         | otherwise
         = case get ix of
               -- Current character is a digit, so add it to the accmulator.
             w | 1# <- w >=# 0x30# 
               , 1# <- w <=# 0x039#
               -> loop neg ( ix +# 1#) 
                           ((n  *# 10#) +# (w -# 0x30#))

               -- Current character is not a digit.
               | otherwise
               -> end neg ix n

        end !neg !ix !n
         -- We didn't find any digits, and there was no explicit sign.
         | 1# <- ix  ==# 0#
         , 1# <- neg ==# 0#
         = (# 0#, 0#, 0# #)

         -- We didn't find any digits, but there was an explicit sign.
         | 1# <- ix  ==# 1#
         , 1# <- neg /=# 0#
         = (# 0#, 0#, 0# #)

         -- Number was explicitly negated.
         | 1# <- neg ==# 1#                    
         , I# n'        <- negate (I# n)
         = (# 1#, n', ix #)

         -- Number was not negated.
         | otherwise
         = (# 1#, n, ix #)
        {-# NOINLINE end #-}
{-# INLINE loadIntWith# #-}


-- | Store an ASCII `Int`, allocating a new buffer.
storeInt :: Int -> IO (F.ForeignPtr Word8)
storeInt i
 = case DC.toFixed 0 (fromIntegral i) of
        BS.PS p _ _     -> return p
{-# INLINE storeInt #-}


