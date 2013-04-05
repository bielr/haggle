{-# LANGUAGE KindSignatures, TypeFamilies #-}
module Data.Graph.Haggle.Interface (
  Vertex(..),
  Edge(..),
  vertexId,
  edgeId,
  edgeSource,
  edgeDest,
  MGraph(..),
  MBidirectional(..),
  Graph(..)
  ) where

import Control.Monad.Primitive

-- | An abstract representation of a vertex.
--
-- Note that the representation is currently exposed.  Do not rely on
-- this, as it is subject to change.
newtype Vertex = V Int
  deriving (Eq, Ord, Show)

-- | An edge between two vertices.
data Edge = E {-# UNPACK #-}!Int {-# UNPACK #-}!Int {-# UNPACK #-}!Int
  deriving (Eq, Ord, Show)

vertexId :: Vertex -> Int
vertexId (V vid) = vid
{-# INLINE vertexId #-}

edgeId :: Edge -> Int
edgeId (E eid _ _) = eid
{-# INLINE edgeId #-}

edgeSource :: Edge -> Vertex
edgeSource (E _ s _) = V s
{-# INLINE edgeSource #-}

edgeDest :: Edge -> Vertex
edgeDest (E _ _ d) = V d
{-# INLINE edgeDest #-}

-- | The interface supported by a mutable graph.
class MGraph (g :: (* -> *) -> *) where
  -- | The type generated by 'freeze'ing a mutable graph
  type ImmutableGraph g

  -- | Create a new graph with an arbitrary amount of storage reserved.
  new :: (PrimMonad m) => m (g m)

  -- | Create a new graph with storage reserved for at least @verts@ and
  --  @edges@.
  --
  --  > g <- newSized verts edges
  newSized :: (PrimMonad m) => Int -> Int -> m (g m)

  -- | Add a new 'Vertex' to the graph, returning its handle.
  addVertex :: (PrimMonad m) => g m -> m Vertex

  -- | Add a new 'Edge' to the graph from @src@ to @dst@.  If either
  -- the source or destination is not in the graph, returns Nothing.
  -- Otherwise, the 'Edge' reference is returned.
  addEdge :: (PrimMonad m) => g m -> Vertex -> Vertex -> m (Maybe Edge)

  -- | List the successors for the given 'Vertex'.
  getSuccessors :: (PrimMonad m) => g m -> Vertex -> m [Vertex]

  -- | Get all of the 'Edge's with the given 'Vertex' as their source.
  getOutEdges :: (PrimMonad m) => g m -> Vertex -> m [Edge]

  -- | Return the number of vertices in the graph
  countVertices :: (PrimMonad m) => g m -> m Int

  -- | Return the number of edges in the graph
  countEdges :: (PrimMonad m) => g m -> m Int

  -- | Edge existence test; this has a default implementation,
  -- but can be overridden if an implementation can support a
  -- better-than-linear version.
  checkEdgeExists :: (PrimMonad m) => g m -> Vertex -> Vertex -> m Bool
  checkEdgeExists g src dst = do
    succs <- getSuccessors g src
    return $ any (==dst) succs

  -- | Freeze the mutable graph into an immutable graph.
  freeze :: (PrimMonad m) => g m -> m (ImmutableGraph g)

-- | An interface for graphs that support looking at predecessor (incoming
-- edges) efficiently.
class (MGraph g) => MBidirectional g where
  getPredecessors :: (PrimMonad m) => g m -> Vertex -> m [Vertex]
  getInEdges :: (PrimMonad m) => g m -> Vertex -> m [Edge]

-- | The basic interface of immutable graphs.
class Graph g where
  type MutableGraph g m
  vertices :: g -> [Vertex]
  edges :: g -> [Edge]
  thaw :: (PrimMonad m) => g -> m (MutableGraph g m)

