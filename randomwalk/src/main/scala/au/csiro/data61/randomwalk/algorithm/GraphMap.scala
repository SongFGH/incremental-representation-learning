package au.csiro.data61.randomwalk.algorithm

import scala.collection.mutable
import scala.collection.mutable.{ArrayBuffer, HashMap}


/**
  *
  */

object GraphMap {

  private lazy val srcVertexMap: mutable.Map[Int, Int] = new HashMap[Int, Int]()
  private lazy val offsets: ArrayBuffer[Int] = new ArrayBuffer()
  private lazy val lengths: ArrayBuffer[Int] = new ArrayBuffer()
  private lazy val edges: ArrayBuffer[(Int, Float)] = new ArrayBuffer()
  private var indexCounter: Int = 0
  private var offsetCounter: Int = 0
  private var firstGet: Boolean = true


  def addVertex(vId: Int, neighbors: Array[(Int, Float)]): Unit = synchronized {
    srcVertexMap.get(vId) match {
      case None => {
        if (!neighbors.isEmpty) {
          updateIndices(vId, neighbors.length)
          for (e <- neighbors) {
            edges.insert(offsetCounter, e)
            offsetCounter += 1
          }
        } else {
          this.addVertex(vId)
        }
      }
      case Some(value) => value
    }
  }

  def getVertices():Array[Int] ={
    val vertices:Array[Int] = srcVertexMap.keys.toArray
    vertices
  }

  private def updateIndices(vId: Int, outDegree: Int): Unit = {
    srcVertexMap.put(vId, indexCounter)
    offsets.insert(indexCounter, offsetCounter)
    lengths.insert(indexCounter, outDegree)
    indexCounter += 1
  }

  def getGraphStatsOnlyOnce: (Int, Int) = synchronized {
    if (firstGet) {
      firstGet = false
      (srcVertexMap.size, offsetCounter)
    }
    else
      (0, 0)
  }

  def resetGetters {
    firstGet = true
  }

  def addVertex(vId: Int): Unit = synchronized {
    srcVertexMap.put(vId, -1)
  }

  def getNumVertices: Int = {
    srcVertexMap.size
  }

  def getNumEdges: Int = {
    offsetCounter
  }

  /**
    * The reset is mainly for the unit test purpose. It does not reset the size of data
    * structures that are initially set by calling setUp function.
    */
  def reset {
    resetGetters
    indexCounter = 0
    offsetCounter = 0
    srcVertexMap.clear()
    offsets.clear()
    lengths.clear()
    edges.clear()
  }

  def getNeighbors(vid: Int): Array[(Int, Float)] = {
    srcVertexMap.get(vid) match {
      case Some(index) =>
        if (index == -1) {
          return Array.empty[(Int, Float)]
        }
        val offset = offsets(index)
        val length = lengths(index)
        edges.slice(offset, offset + length).toArray
      case None => null
    }
  }
}
