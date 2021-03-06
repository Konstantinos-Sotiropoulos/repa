
module Data.Repa.Convert.Format.Tup
        (Tup (..))
where
import Data.Repa.Convert.Format.Sep
import Data.Repa.Convert.Format.Binary
import Data.Repa.Convert.Format.Base
import Data.Repa.Scalar.Product
import Data.Monoid
import Data.Word
import Data.Char


-- | Display fields as a tuple, like @(x,y,z)@.
data Tup f
        = Tup f
        deriving Show


---------------------------------------------------------------------------------------------------
instance Format (Tup ()) where
 type Value (Tup ())    = ()
 fieldCount (Tup _)     = 0
 minSize    (Tup _)     = 0
 fixedSize  (Tup _)     = return 0
 packedSize (Tup _) ()  = return 0
 {-# INLINE minSize    #-}
 {-# INLINE fieldCount #-}
 {-# INLINE fixedSize  #-}
 {-# INLINE packedSize #-}


instance Packable (Tup ()) where
 pack   _fmt _val       = mempty
 unpack _fmt            = return ()
 {-# INLINE pack   #-}
 {-# INLINE unpack #-}


---------------------------------------------------------------------------------------------------
instance ( Format f1
         , Format (Tup fs)
         , Format (Sep fs)
         , Value  (Sep fs) ~ Value fs)
        => Format (Tup (f1 :*: fs)) where

 type Value (Tup (f1 :*: fs)) 
        = Value f1 :*: Value fs

 fieldCount (Tup (_  :*: fs))
  = 1 + fieldCount (Tup fs)

 minSize    (Tup (f1 :*: fs))
  = let !n      = fieldCount (Tup fs)
    in  2 + minSize f1
          + (if n == 0 then 0 else 1) 
          + minSize (Sep ',' fs)

 fixedSize  (Tup (f1 :*: fs))
  = do  s1      <- fixedSize f1
        ss      <- fixedSize (Sep ',' fs)
        let sSep = if fieldCount (Sep ',' fs) == 0 then 0 else 1
        return  $ 2 + s1 + sSep + ss

 packedSize (Tup (f1 :*: fs)) (x1 :*: xs)
  = do  s1      <- packedSize f1 x1
        ss      <- packedSize (Sep ',' fs) xs
        let sSep = if fieldCount (Sep ',' fs) == 0 then 0 else 1
        return  $ 2 + s1 + sSep + ss 
 {-# INLINE minSize    #-}
 {-# INLINE fieldCount #-}
 {-# INLINE fixedSize  #-}
 {-# INLINE packedSize #-}


instance ( Packable f1
         , Packable (Sep fs)
         , Format (Tup fs)
         , Value  (Sep fs) ~ Value fs)
       => Packable (Tup (f1 :*: fs)) where

 pack   (Tup fs) xs
        =  pack Word8be (cw8 '(')
        <> pack (Sep ',' fs) xs
        <> pack Word8be (cw8 ')')
 {-# INLINE pack #-}

 -- TODO: finish tuple decoding.
 unpack = error "repa-convert.row unpack finish me"
 {-# INLINE unpack #-}


---------------------------------------------------------------------------------------------------
cw8 :: Char -> Word8
cw8 c = fromIntegral $ ord c
{-# INLINE cw8 #-}

