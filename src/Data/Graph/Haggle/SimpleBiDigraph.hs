{-# LANGUAGE TypeFamilies #-}
-- | This is a simple graph (it does not allow parallel edges).  To support
-- this efficiently, it is less compact than 'Digraph' or 'BiDigraph'.  As
-- a consequence, edge existence tests are efficient (logarithmic in the
-- number of edges leaving the source vertex).
module Data.Graph.Haggle.SimpleBiDigraph (
  MSimpleBiDigraph,
  SimpleBiDigraph,
  newMSimpleBiDigraph,
  newSizedMSimpleBiDigraph
  ) where

import Control.Monad ( when )
import Control.Monad.Primitive
import Data.PrimRef
import Data.IntMap ( IntMap )
import qualified Data.IntMap as IM
import qualified Data.Vector.Mutable as MV
import qualified Data.Vector as V

import Data.Graph.Haggle
import Data.Graph.Haggle.Internal.Basic

type EdgeID = Int

data MSimpleBiDigraph m = -- See Note [Graph Representation]
  MBiDigraph { mgraphVertexCount :: PrimRef m Int
             , mgraphEdgeCount :: PrimRef m Int
             , mgraphPreds :: PrimRef m (MV.MVector (PrimState m) (IntMap EdgeID))
             , mgraphSuccs :: PrimRef m (MV.MVector (PrimState m) (IntMap EdgeID))
             }

data SimpleBiDigraph =
  BiDigraph { vertexCount :: {-# UNPACK #-} !Int
            , edgeCount :: {-# UNPACK #-} !Int
            , graphPreds :: V.Vector (IntMap EdgeID)
            , graphSuccs :: V.Vector (IntMap EdgeID)
            }

defaultSize :: Int
defaultSize = 128

newMSimpleBiDigraph :: (PrimMonad m) => m (MSimpleBiDigraph m)
newMSimpleBiDigraph = newSizedMSimpleBiDigraph defaultSize 0

newSizedMSimpleBiDigraph :: (PrimMonad m) => Int -> Int -> m (MSimpleBiDigraph m)
newSizedMSimpleBiDigraph szNodes _ = do
  when (szNodes < 0) $ error "Negative size (newSized)"
  nn <- newPrimRef 0
  en <- newPrimRef 0
  pvec <- MV.new szNodes
  svec <- MV.new szNodes
  pref <- newPrimRef pvec
  sref <- newPrimRef svec
  return $! MBiDigraph { mgraphVertexCount = nn
                       , mgraphEdgeCount = en
                       , mgraphPreds = pref
                       , mgraphSuccs = sref
                       }

instance MGraph MSimpleBiDigraph where
  type ImmutableGraph MSimpleBiDigraph = SimpleBiDigraph
  getOutEdges g (V src) = do
    nVerts <- readPrimRef (mgraphVertexCount g)
    case src >= nVerts of
      True -> return []
      False -> do
        svec <- readPrimRef (mgraphSuccs g)
        succs <- MV.read svec src
        return $ IM.foldrWithKey' (\dst eid acc -> E eid src dst : acc) [] succs

  countVertices = readPrimRef . mgraphVertexCount
  countEdges = readPrimRef . mgraphEdgeCount

  getSuccessors g (V src) = do
    nVerts <- readPrimRef (mgraphVertexCount g)
    case src >= nVerts of
      True -> return []
      False -> do
        svec <- readPrimRef (mgraphSuccs g)
        succs <- MV.read svec src
        return $ map V $ IM.keys succs

  checkEdgeExists g (V src) (V dst) = do
    nVerts <- readPrimRef (mgraphVertexCount g)
    case src >= nVerts || dst >= nVerts of
      True -> return False
      False -> do
        svec <- readPrimRef (mgraphSuccs g)
        succs <- MV.read svec src
        return $ IM.member dst succs

  freeze g = do
    nVerts <- readPrimRef (mgraphVertexCount g)
    nEdges <- readPrimRef (mgraphEdgeCount g)
    pvec <- readPrimRef (mgraphPreds g)
    svec <- readPrimRef (mgraphSuccs g)
    pvec' <- V.freeze (MV.take nVerts pvec)
    svec' <- V.freeze (MV.take nVerts svec)
    return $! BiDigraph { vertexCount = nVerts
                        , edgeCount = nEdges
                        , graphPreds = pvec'
                        , graphSuccs = svec'
                        }

instance MAddVertex MSimpleBiDigraph where
  addVertex g = do
    ensureNodeSpace g
    vid <- readPrimRef r
    modifyPrimRef' r (+1)
    pvec <- readPrimRef (mgraphPreds g)
    svec <- readPrimRef (mgraphSuccs g)
    MV.write pvec vid IM.empty
    MV.write svec vid IM.empty
    return (V vid)
    where
      r = mgraphVertexCount g

instance MAddEdge MSimpleBiDigraph where
  addEdge g v1@(V src) v2@(V dst) = do
    nVerts <- readPrimRef (mgraphVertexCount g)
    exists <- checkEdgeExists g v1 v2
    case exists || src >= nVerts || dst >= nVerts of
      True -> return Nothing
      False -> do
        eid <- readPrimRef (mgraphEdgeCount g)
        modifyPrimRef' (mgraphEdgeCount g) (+1)

        pvec <- readPrimRef (mgraphPreds g)
        preds <- MV.read pvec dst
        MV.write pvec dst (IM.insert src eid preds)

        svec <- readPrimRef (mgraphSuccs g)
        succs <- MV.read svec src
        MV.write svec src (IM.insert dst eid succs)

        return $ Just (E eid src dst)

instance MBidirectional MSimpleBiDigraph where
  getPredecessors g (V vid) = do
    nVerts <- readPrimRef (mgraphVertexCount g)
    case vid < nVerts of
      False -> return []
      True -> do
        pvec <- readPrimRef (mgraphPreds g)
        preds <- MV.read pvec vid
        return $ map V $ IM.keys preds

  getInEdges g (V vid) = do
    nVerts <- readPrimRef (mgraphVertexCount g)
    case vid < nVerts of
      False -> return []
      True -> do
        pvec <- readPrimRef (mgraphPreds g)
        preds <- MV.read pvec vid
        return $ IM.foldrWithKey' (\src eid acc -> E eid src vid : acc) [] preds

instance Graph SimpleBiDigraph where
  type MutableGraph SimpleBiDigraph = MSimpleBiDigraph
  -- FIXME: This will be more complicated if we support removing vertices
  vertices g = map V [0 .. vertexCount g - 1]
  edges g = concatMap (outEdges g) (vertices g)
  successors g (V v)
    | outOfRange g v = []
    | otherwise = map V $ IM.keys $ V.unsafeIndex (graphSuccs g) v
  outEdges g (V v)
    | outOfRange g v = []
    | otherwise =
      let succs = V.unsafeIndex (graphSuccs g) v
      in IM.foldrWithKey' (\dst eid acc -> E eid v dst : acc) [] succs
  edgeExists g (V src) (V dst)
    | outOfRange g src || outOfRange g dst = False
    | otherwise = IM.member dst (V.unsafeIndex (graphSuccs g) src)
  maxVertexId g = V.length (graphSuccs g) - 1
  isEmpty = (==0) . vertexCount
  thaw g = do
    vc <- newPrimRef (vertexCount g)
    ec <- newPrimRef (edgeCount g)
    pvec <- V.thaw (graphPreds g)
    svec <- V.thaw (graphSuccs g)
    pref <- newPrimRef pvec
    sref <- newPrimRef svec
    return MBiDigraph { mgraphVertexCount = vc
                      , mgraphEdgeCount = ec
                      , mgraphPreds = pref
                      , mgraphSuccs = sref
                      }


instance Bidirectional SimpleBiDigraph  where
  predecessors g (V v)
    | outOfRange g v = []
    | otherwise = map V $ IM.keys $ V.unsafeIndex (graphPreds g) v
  inEdges g (V v)
    | outOfRange g v = []
    | otherwise =
      let preds = V.unsafeIndex (graphPreds g) v
      in IM.foldrWithKey' (\src eid acc -> E eid src v : acc) [] preds

-- Helpers

outOfRange :: SimpleBiDigraph -> Int -> Bool
outOfRange g = (>= vertexCount g)

-- | Given a graph, ensure that there is space in the vertex vector
-- for a new vertex.  If there is not, double the capacity.
ensureNodeSpace :: (PrimMonad m) => MSimpleBiDigraph m -> m ()
ensureNodeSpace g = do
  pvec <- readPrimRef (mgraphPreds g)
  svec <- readPrimRef (mgraphSuccs g)
  let cap = MV.length pvec
  cnt <- readPrimRef (mgraphVertexCount g)
  case cnt < cap of
    True -> return ()
    False -> do
      pvec' <- MV.grow pvec cap
      svec' <- MV.grow svec cap
      writePrimRef (mgraphPreds g) pvec'
      writePrimRef (mgraphSuccs g) svec'


{- Note [Graph Representation]

Each of the IntMaps in the vectors maps the edge *destination* node id to the
*edge id*.  We need to store the edge IDs to reconstruct an Edge.  Other graph
representations use the edge IDs to maintain lists, but here we don't have
that.  The destination is the key of the map for fast edgeExists tests.

-}
