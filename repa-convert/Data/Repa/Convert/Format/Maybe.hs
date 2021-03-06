
-- | Maybe -like formats.
module Data.Repa.Convert.Format.Maybe
        ( MaybeAsc      (..))
where
import Data.Repa.Convert.Format.Lists
import Data.Repa.Convert.Format.Binary
import Data.Repa.Convert.Format.Base
import Prelude hiding (fail)


------------------------------------------------------------------------------------------ MaybeAsc
-- | Maybe an Ascii string or something else.
data MaybeAsc f = MaybeAsc String f      deriving (Eq, Show)
instance Format f => Format (MaybeAsc f) where
 type Value (MaybeAsc f)   = Maybe (Value f)
 fieldCount _              = 1
 {-# INLINE fieldCount #-}

 minSize    (MaybeAsc s f) 
  = min (length s) (minSize f)
 {-# INLINE minSize    #-}

 fixedSize  (MaybeAsc s f)
  = case fixedSize f of
        Nothing -> Nothing
        Just sf -> if length s == sf 
                        then Just sf
                        else Nothing
 {-# INLINE fixedSize  #-}

 packedSize (MaybeAsc str f) mv
  = case mv of
        Nothing -> Just $ length str
        Just v  -> packedSize f v
 {-# INLINE packedSize #-}


instance Packable f
      => Packable (MaybeAsc f) where
 pack  (MaybeAsc str f) mv
  = case mv of
        Nothing -> pack VarAsc str
        Just v  -> pack f      v
 {-# INLINE pack #-}

 unpack (MaybeAsc str f)
  =  Unpacker $ \start end stop fail eat
  -> do (ptr, str')     <- unpackAsc start end stop
        if str == str'
         then eat ptr Nothing
         else (fromUnpacker $ unpack f) start end stop fail 
               $ \ptr' x -> eat ptr' (Just x)
 {-# INLINE unpack #-}

