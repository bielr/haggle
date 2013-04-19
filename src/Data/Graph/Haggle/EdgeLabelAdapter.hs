{-# LANGUAGE TypeFamilies #-}
-- | This adapter adds edge labels (but not vertex labels) to graphs.
--
-- It only supports 'addLabeledEdge', not 'addEdge'.  See 'LabeledGraph'
-- for more details.
module Data.Graph.Haggle.EdgeLabelAdapter (
  EdgeLabeledMGraph,
  EdgeLabeledGraph,
  newEdgeLabeledGraph,
  newSizedEdgeLabeledGraph,
  mapEdgeLabel
  ) where

import Control.Monad.ST
import qualified Data.Graph.Haggle as I
import qualified Data.Graph.Haggle.Internal.Adapter as A

newtype EdgeLabeledMGraph g el s = ELMG { unELMG :: A.LabeledMGraph g () el s }
newtype EdgeLabeledGraph g el = ELG { unELG :: A.LabeledGraph g () el }

mapEdgeLabel :: EdgeLabeledGraph g el -> (el -> el') -> EdgeLabeledGraph g el'
mapEdgeLabel g = ELG . A.mapEdgeLabel (unELG g)
{-# INLINE mapEdgeLabel #-}

vertices :: (I.Graph g) => EdgeLabeledGraph g el -> [I.Vertex]
vertices = I.vertices . unELG
{-# INLINE vertices #-}

edges :: (I.Graph g) => EdgeLabeledGraph g el -> [I.Edge]
edges = I.edges . unELG
{-# INLINE edges #-}

successors :: (I.Graph g) => EdgeLabeledGraph g el -> I.Vertex -> [I.Vertex]
successors (ELG lg) = I.successors lg
{-# INLINE successors #-}

outEdges :: (I.Graph g) => EdgeLabeledGraph g el -> I.Vertex -> [I.Edge]
outEdges (ELG lg) = I.outEdges lg
{-# INLINE outEdges #-}

edgeExists :: (I.Graph g) => EdgeLabeledGraph g el -> I.Vertex -> I.Vertex -> Bool
edgeExists (ELG lg) = I.edgeExists lg
{-# INLINE edgeExists #-}

maxVertexId :: (I.Graph g) => EdgeLabeledGraph g el -> Int
maxVertexId = I.maxVertexId . unELG
{-# INLINE maxVertexId #-}

isEmpty :: (I.Graph g) => EdgeLabeledGraph g el -> Bool
isEmpty = I.isEmpty . unELG
{-# INLINE isEmpty #-}

instance (I.Graph g) => I.Graph (EdgeLabeledGraph g el) where
  type MutableGraph (EdgeLabeledGraph g el) =
    EdgeLabeledMGraph (I.MutableGraph g) el
  vertices = vertices
  edges = edges
  successors = successors
  outEdges = outEdges
  edgeExists = edgeExists
  maxVertexId = maxVertexId
  isEmpty = isEmpty
  thaw (ELG lg) = do
    g' <- I.thaw lg
    return $ ELMG g'

predecessors :: (I.Bidirectional g) => EdgeLabeledGraph g el -> I.Vertex -> [I.Vertex]
predecessors (ELG lg) = I.predecessors lg
{-# INLINE predecessors #-}

inEdges :: (I.Bidirectional g) => EdgeLabeledGraph g el -> I.Vertex -> [I.Edge]
inEdges (ELG lg) = I.inEdges lg
{-# INLINE inEdges #-}

instance (I.Bidirectional g) => I.Bidirectional (EdgeLabeledGraph g el) where
  predecessors = predecessors
  inEdges = inEdges

edgeLabel :: (I.Graph g) => EdgeLabeledGraph g el -> I.Edge -> Maybe el
edgeLabel (ELG lg) = I.edgeLabel lg
{-# INLINE edgeLabel #-}

labeledEdges :: (I.Graph g) => EdgeLabeledGraph g el -> [(I.Edge, el)]
labeledEdges = I.labeledEdges . unELG
{-# INLINE labeledEdges #-}

instance (I.Graph g) => I.HasEdgeLabel (EdgeLabeledGraph g el) where
  type EdgeLabel (EdgeLabeledGraph g el) = el
  edgeLabel = edgeLabel
  labeledEdges = labeledEdges

newEdgeLabeledGraph :: (I.MGraph g)
                    => ST s (g s)
                    -> ST s (EdgeLabeledMGraph g nl s)
newEdgeLabeledGraph newG = do
  g <- A.newLabeledGraph newG
  return $ ELMG g
{-# INLINE newEdgeLabeledGraph #-}

newSizedEdgeLabeledGraph :: (I.MGraph g)
                         => (Int -> Int -> ST s (g s))
                         -> Int
                         -> Int
                         -> ST s (EdgeLabeledMGraph g el s)
newSizedEdgeLabeledGraph newG szV szE = do
  g <- A.newSizedLabeledGraph newG szV szE
  return $ ELMG g
{-# INLINE newSizedEdgeLabeledGraph #-}

addLabeledEdge :: (I.MGraph g, I.MAddEdge g)
               => EdgeLabeledMGraph g el s
               -> I.Vertex
               -> I.Vertex
               -> el
               -> ST s (Maybe I.Edge)
addLabeledEdge lg = I.addLabeledEdge (unELMG lg)
{-# INLINE addLabeledEdge #-}

addVertex :: (I.MGraph g, I.MAddVertex g)
          => EdgeLabeledMGraph g el s
          -> ST s I.Vertex
addVertex lg = I.addVertex (A.rawMGraph (unELMG lg))
{-# INLINE addVertex #-}

unsafeGetEdgeLabel :: (I.MGraph g, I.MAddEdge g)
                   => EdgeLabeledMGraph g el s
                   -> I.Edge
                   -> ST s el
unsafeGetEdgeLabel (ELMG g) e =
  I.unsafeGetEdgeLabel g e
{-# INLINE unsafeGetEdgeLabel #-}

getSuccessors :: (I.MGraph g)
              => EdgeLabeledMGraph g el s
              -> I.Vertex
              -> ST s [I.Vertex]
getSuccessors lg = I.getSuccessors (unELMG lg)
{-# INLINE getSuccessors #-}

getOutEdges :: (I.MGraph g)
            => EdgeLabeledMGraph g el s -> I.Vertex -> ST s [I.Edge]
getOutEdges lg = I.getOutEdges (unELMG lg)
{-# INLINE getOutEdges #-}

countVertices :: (I.MGraph g) => EdgeLabeledMGraph g el s -> ST s Int
countVertices = I.countVertices . unELMG
{-# INLINE countVertices #-}

getVertices :: (I.MGraph g) => EdgeLabeledMGraph g el s -> ST s [I.Vertex]
getVertices = I.getVertices . unELMG
{-# INLINE getVertices #-}

countEdges :: (I.MGraph g) => EdgeLabeledMGraph g el s -> ST s Int
countEdges = I.countEdges . unELMG
{-# INLINE countEdges #-}

getPredecessors :: (I.MBidirectional g)
                => EdgeLabeledMGraph g el s -> I.Vertex -> ST s [I.Vertex]
getPredecessors lg = I.getPredecessors (unELMG lg)
{-# INLINE getPredecessors #-}

getInEdges :: (I.MBidirectional g)
           => EdgeLabeledMGraph g el s -> I.Vertex -> ST s [I.Edge]
getInEdges lg = I.getInEdges (unELMG lg)
{-# INLINE getInEdges #-}

checkEdgeExists :: (I.MGraph g)
                => EdgeLabeledMGraph g el s
                -> I.Vertex
                -> I.Vertex
                -> ST s Bool
checkEdgeExists lg = I.checkEdgeExists (unELMG lg)
{-# INLINE checkEdgeExists #-}

freeze :: (I.MGraph g)
       => EdgeLabeledMGraph g el s
       -> ST s (EdgeLabeledGraph (I.ImmutableGraph g) el)
freeze lg = do
  g' <- I.freeze (unELMG lg)
  return $ ELG g'
{-# INLINE freeze #-}

instance (I.MGraph g) => I.MGraph (EdgeLabeledMGraph g el) where
  type ImmutableGraph (EdgeLabeledMGraph g el) =
    EdgeLabeledGraph (I.ImmutableGraph g) el
  getVertices = getVertices
  getSuccessors = getSuccessors
  getOutEdges = getOutEdges
  countVertices = countVertices
  countEdges = countEdges
  checkEdgeExists = checkEdgeExists
  freeze = freeze

instance (I.MBidirectional g) => I.MBidirectional (EdgeLabeledMGraph g el) where
  getPredecessors = getPredecessors
  getInEdges = getInEdges

instance (I.MAddVertex g) => I.MAddVertex (EdgeLabeledMGraph g el) where
  addVertex = addVertex

instance (I.MAddEdge g) => I.MLabeledEdge (EdgeLabeledMGraph g el) where
  type MEdgeLabel (EdgeLabeledMGraph g el) = el
  getEdgeLabel = getEdgeLabel
  addLabeledEdge = addLabeledEdge

