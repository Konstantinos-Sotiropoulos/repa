{-# LANGUAGE TypeOperators, PatternGuards, RankNTypes, ScopedTypeVariables, BangPatterns, FlexibleContexts #-}
{-# OPTIONS -fno-warn-incomplete-patterns #-}

-- | Fast computation of Discrete Fourier Transforms using the Cooley-Tuckey algorithm. 
--   Time complexity is O(n log n) in the size of the input. 
--
--   This uses a naive divide-and-conquer algorithm, the absolute performance is about
--   50x slower than FFTW in estimate mode.
--
module Data.Array.Repa.Algorithms.FFT
	( Mode(..)
	, isPowerOfTwo
	, fft3d
	, fft2d
	, fft1d)
where
import Data.Array.Repa.Algorithms.Complex
import Data.Array.Repa				as A
import Data.Array.Repa.Repr.Unboxed		as A
import Prelude                                  as P

data Mode
	= Forward
	| Reverse
	| Inverse
	deriving (Show, Eq)

{-# INLINE signOfMode #-}
signOfMode :: Mode -> Double
signOfMode mode
 = case mode of
	Forward		-> (-1)
	Reverse		->   1
	Inverse		->   1


{-# INLINE isPowerOfTwo #-}
-- | Check if an `Int` is a power of two.
isPowerOfTwo :: Int -> Bool
isPowerOfTwo n
	| 0	<- n		= True
	| 2	<- n		= True
	| n `mod` 2 == 0	= isPowerOfTwo (n `div` 2)
	| otherwise		= False


-- 3D Transform -----------------------------------------------------------------------------------
-- | Compute the DFT of a 3d array. Array dimensions must be powers of two else `error`.
fft3d 	:: Mode
	-> Array U DIM3 Complex
	-> Array U DIM3 Complex

fft3d mode arr
 = let	_ :. depth :. height :. width	= extent arr
	!sign	= signOfMode mode
	!scale 	= fromIntegral (depth * width * height) 
		
   in	if not (isPowerOfTwo depth && isPowerOfTwo height && isPowerOfTwo width)
	 then error $ unlines
	        [ "Data.Array.Repa.Algorithms.FFT: fft3d"
	        , "  Array dimensions must be powers of two,"
	        , "  but the provided array is " 
	                P.++ show height P.++ "x" P.++ show width P.++ "x" P.++ show depth ]
	           
	 else arr `deepSeqArray` 
		case mode of
			Forward	-> fftTrans3d sign $ fftTrans3d sign $ fftTrans3d sign arr
			Reverse	-> fftTrans3d sign $ fftTrans3d sign $ fftTrans3d sign arr
			Inverse	-> forceUnboxed 
			        $ A.map (/ scale) 
				$ fftTrans3d sign $ fftTrans3d sign $ fftTrans3d sign arr

fftTrans3d 
	:: Double
	-> Array U DIM3 Complex 
	-> Array U DIM3 Complex

{-# NOINLINE fftTrans3d #-}
fftTrans3d sign arr
 = let	(sh :. len)	= extent arr
   in	forceUnboxed $ rotate3d $ fft sign sh len arr


rotate3d 
        :: Repr r Complex
        => Array r DIM3 Complex -> Array D DIM3 Complex
{-# INLINE rotate3d #-}
rotate3d arr
 = backpermute (sh :. m :. k :. l) f arr
 where	(sh :. k :. l :. m)		= extent arr
	f (sh' :. m' :. k' :. l')	= sh' :. k' :. l' :. m'



-- Matrix Transform -------------------------------------------------------------------------------
-- | Compute the DFT of a matrix. Array dimensions must be powers of two else `error`.
fft2d 	:: Mode
	-> Array U DIM2 Complex
	-> Array U DIM2 Complex

fft2d mode arr
 = let	_ :. height :. width	= extent arr
	sign	= signOfMode mode
	scale 	= fromIntegral (width * height) 
		
   in	if not (isPowerOfTwo height && isPowerOfTwo width)
	 then error $ unlines
	        [ "Data.Array.Repa.Algorithms.FFT: fft2d"
	        , "  Array dimensions must be powers of two,"
	        , "  but the provided array is " P.++ show height P.++ "x" P.++ show width ]
	 
	 else arr `deepSeqArray` 
		case mode of
			Forward	-> fftTrans2d sign $ fftTrans2d sign arr
			Reverse	-> fftTrans2d sign $ fftTrans2d sign arr
			Inverse	-> forceUnboxed $ A.map (/ scale) $ fftTrans2d sign $ fftTrans2d sign arr

fftTrans2d 
	:: Double
	-> Array U DIM2 Complex 
	-> Array U DIM2 Complex

{-# NOINLINE fftTrans2d #-}
fftTrans2d sign arr
 = let  (sh :. len)	= extent arr
   in	forceUnboxed $ transpose $ fft sign sh len arr


-- Vector Transform -------------------------------------------------------------------------------
-- | Compute the DFT of a vector. Array dimensions must be powers of two else `error`.
fft1d	:: Mode 
	-> Array U DIM1 Complex 
	-> Array U DIM1 Complex
	
fft1d mode arr
 = let	_ :. len	= extent arr
	sign	= signOfMode mode
	scale	= fromIntegral len
	
   in	if not $ isPowerOfTwo len
	 then error $ unlines 
                [ "Data.Array.Repa.Algorithms.FFT: fft1d"
	        , "  Array dimensions must be powers of two, "
                , "  but the provided array is " P.++ show len ]
	      
	 else arr `deepSeqArray`
		case mode of
			Forward	-> fftTrans1d sign arr
			Reverse	-> fftTrans1d sign arr
			Inverse -> forceUnboxed $ A.map (/ scale) $ fftTrans1d sign arr

fftTrans1d
	:: Double 
	-> Array U DIM1 Complex
	-> Array U DIM1 Complex

{-# NOINLINE fftTrans1d #-}
fftTrans1d sign arr
 = let	(sh :. len)	= extent arr
   in	fft sign sh len arr


-- Rank Generalised Worker ------------------------------------------------------------------------
fft     :: Shape sh 
        => Double -> sh -> Int 
        -> Array U (sh :. Int) Complex
        -> Array U (sh :. Int) Complex

{-# INLINE fft #-}
fft !sign !sh !lenVec !vec
 = go lenVec 0 1
 where	go !len !offset !stride
	 | len == 2
	 = forceUnboxed $ fromFunction (sh :. 2) swivel
	
	 | otherwise
	 = combine len 
		(go (len `div` 2) offset            (stride * 2))
		(go (len `div` 2) (offset + stride) (stride * 2))

	 where	swivel (sh' :. ix)
		 = case ix of
			0	-> (vec `unsafeIndex` (sh' :. offset)) + (vec `unsafeIndex` (sh' :. (offset + stride)))
			1	-> (vec `unsafeIndex` (sh' :. offset)) - (vec `unsafeIndex` (sh' :. (offset + stride)))

		{-# INLINE combine #-}
		combine !len' 	evens odds
 	 	 = evens `deepSeqArray` odds `deepSeqArray`
   	   	   let	odds'	= unsafeTraverse odds id (\get ix@(_ :. k) -> twiddle sign k len' * get ix) 
   	   	   in	forceUnboxed $ (evens +^ odds') A.++ (evens -^ odds')


-- Compute a twiddle factor.
twiddle :: Double
	-> Int 			-- index
	-> Int 			-- length
	-> Complex

{-# INLINE twiddle #-}
twiddle sign k' n'
 	=  (cos (2 * pi * k / n), sign * sin  (2 * pi * k / n))
	where 	k	= fromIntegral k'
		n	= fromIntegral n'
