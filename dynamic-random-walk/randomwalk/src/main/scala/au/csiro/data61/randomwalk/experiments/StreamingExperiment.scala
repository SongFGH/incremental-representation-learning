package au.csiro.data61.randomwalk.experiments

import au.csiro.data61.randomwalk.algorithm.{GraphMap, UniformRandomWalk}
import au.csiro.data61.randomwalk.common.CommandParser.RrType
import au.csiro.data61.randomwalk.common._

import scala.collection.JavaConverters._
import scala.collection.mutable
import scala.collection.parallel.ParSeq
import scala.util.Random
import scala.util.control.Breaks._

/**
  * Created by Hooman on 2018-04-11.
  */
case class StreamingExperiment(config: Params) {
  val fm = FileManager(config)
  val rwalk = UniformRandomWalk(config)

  def streamEdges(): Unit = {
    var numSteps = Array.empty[Array[Int]]
    var numWalkers = Array.empty[Array[Int]]
    var stepTimes = Array.empty[Array[Long]]
    var meanErrors = Array.empty[Array[Double]]
    var maxErrors = Array.empty[Array[Double]]

    for (nr <- 0 until config.numRuns) {
      var graphStats = Seq.empty[(Int, Int, Int, Int)]
      var totalTime: Long = 0
      GraphMap.reset
      WalkStorage.reset
      var prevWalks = ParSeq.empty[(Int, Int, Int, Seq[Int])]

      println("******* Building the graph ********")
      if (config.fixedGraph) {
        Random.setSeed(config.seed)
      } else {
        Random.setSeed(config.seed + nr)
      }

      val (initEdges, edges) = config.grouped match {
        case false => fm.readPartitionEdgeListWithInitEdges()
        case true => fm.readAlreadyPartitionedEdgeList()
      }

      Random.setSeed(config.seed + nr)

      val logSize = Math.min(edges.length, config.maxSteps) + 1
      if (numSteps.isEmpty) {
        numSteps = Array.ofDim[Int](config.numRuns, logSize)
        numWalkers = Array.ofDim[Int](config.numRuns, logSize)
        stepTimes = Array.ofDim[Long](config.numRuns, logSize)
        meanErrors = Array.ofDim[Double](config.numRuns, logSize)
        maxErrors = Array.ofDim[Double](config.numRuns, logSize)
      }

      // Construct initial graph
      println("******* Initialized Graph the graph ********")
      var afs = mutable.HashSet.empty[Int]
      var biggestScc = Seq.empty[Int]
      if (!initEdges.isEmpty) {
        val updateResult = updateGraph(initEdges)

        val numEdges = GraphMap.getNumEdges
        val numVertices = GraphMap.getNumVertices
        afs = updateResult._1
        val comps = updateResult._2
        biggestScc = comps._3
        println(s"Number of edges: ${numEdges}")
        println(s"Number of vertices: ${numVertices}")
        if (config.countSccs) {
          println(s"Size of biggest SCC: ${biggestScc.size}")
          println(s"Number of SCCs: ${comps._1}")
        }
        val result = streamingAddAndRun(afs, prevWalks)
        prevWalks = result._1
        totalTime = result._4
        numSteps(nr)(0) = result._2
        numWalkers(nr)(0) = result._3
        stepTimes(nr)(0) = result._4
        graphStats ++= Seq((numVertices, numEdges, comps._1, comps._2))
        if (config.logErrors) {
          val (meanE, maxE): (Double, Double) = GraphUtils.computeErrorsMeanAndMax(result
            ._1, config)
          meanErrors(nr)(0) = meanE
          maxErrors(nr)(0) = maxE
          println(s"Mean Error: ${meanE}")
          println(s"Max Error: ${maxE}")
        }
        println(s"Total random walk time: $totalTime")
      } else {
        println("Initial graph is empty.")
      }
      println("Writing outputs...")
      fm.saveAffectedVertices(
        afs, s"${Property.afsSuffix}-${config.rrType.toString}-wl${
          config
            .walkLength
        }-nw${config.numWalks}-0-$nr")
      if (config.countSccs) {
        fm.saveBiggestScc(
          biggestScc, s"${Property.biggestScc}-${config.rrType.toString}-wl${
            config
              .walkLength
          }-nw${config.numWalks}-0-$nr")
      }
      fm.savePaths(prevWalks, s"${config.rrType.toString}-wl${config.walkLength}-nw${
        config.numWalks
      }-0-$nr")
      fm.saveDegrees(GraphUtils.degrees(), s"${Property.degreeSuffix}-${
        config.rrType
          .toString
      }-wl${config.walkLength}-nw${config.numWalks}-0-$nr")

      breakable {
        println("Start streaming...")
        for (ec <- 1 until edges.length + 1) {
          val (step, updates) = edges(ec - 1)
          if (ec > config.maxSteps)
            break
          val updateResult = updateGraph(updates)
          afs = updateResult._1
          val comps = updateResult._2
          biggestScc = comps._3
          val result = streamingAddAndRun(afs, prevWalks)
          prevWalks = result._1
          val ns = result._2
          val nw = result._3
          val stepTime = result._4

          val numEdges = GraphMap.getNumEdges
          val numVertices = GraphMap.getNumVertices

          totalTime += stepTime

          numSteps(nr)(ec) = ns
          numWalkers(nr)(ec) = nw
          stepTimes(nr)(ec) = stepTime
          graphStats ++= Seq((numVertices, numEdges, comps._1, comps._2))

          println(s"Step ID: ${step}")
          println(s"Step time: $stepTime")
          println(s"Total time: $totalTime")
          println(s"Number of edges: ${numEdges}")
          println(s"Number of vertices: ${numVertices}")
          println(s"Number of walks: ${prevWalks.size}")
          if (config.countSccs) {
            println(s"Size of biggest SCC: ${biggestScc.size}")
            println(s"Number of SCCs: ${comps._1}")
          }
          if (config.logErrors) {
            val (meanE, maxE): (Double, Double) = GraphUtils.computeErrorsMeanAndMax(result._1,
              config)
            meanErrors(nr)(ec) = meanE
            maxErrors(nr)(ec) = maxE
            println(s"Mean Error: ${meanE}")
            println(s"Max Error: ${maxE}")
          }
          println(s"Number of actual steps: $ns")
          println(s"Number of actual walks: $nw")

          if (ec % config.savePeriod == 0) {
            fm.saveAffectedVertices(
              afs, s"${Property.afsSuffix}-${config.rrType.toString}-wl${
                config
                  .walkLength
              }-nw${config.numWalks}-$step-$nr")
            if (config.countSccs) {
              fm.saveBiggestScc(
                biggestScc, s"${Property.biggestScc}-${config.rrType.toString}-wl${
                  config
                    .walkLength
                }-nw${config.numWalks}-$step-$nr")
            }
            fm.savePaths(prevWalks, s"${config.rrType.toString}-wl${
              config
                .walkLength
            }-nw${
              config.numWalks
            }-$step-$nr")
            fm.saveDegrees(GraphUtils.degrees(), s"${Property.degreeSuffix}-${
              config.rrType
                .toString
            }-wl${config.walkLength}-nw${config.numWalks}-$step-$nr")
          }
        }
      }
      fm.saveGraphStats(graphStats, s"${
        config.rrType
          .toString
      }-${Property.graphStatsSuffix}-wl${config.walkLength}-nw${config.numWalks}-$nr")

    }
    fm.saveComputations(numSteps, Property.stepsToCompute.toString)
    fm.saveComputations(numWalkers, Property.walkersToCompute.toString)
    fm.saveTimeSteps(stepTimes, Property.timesToCompute.toString)
    if (config.logErrors) {
      fm.saveErrors(meanErrors, Property.meanErrors.toString)
      fm.saveErrors(maxErrors, Property.maxErrors.toString)
    }
  }

  def updateGraph(updates: Seq[(Int, Int)]): (mutable.HashSet[Int], (Int, Int, Seq[Int])) = {
    val afs = new mutable.HashSet[Int]()
    for (u <- updates) {
      val src = u._1
      val dst = u._2
      val w = 1f
      var sNeighbors = GraphMap.getNeighbors(src)
      var dNeighbors = GraphMap.getNeighbors(dst)
      sNeighbors ++= Seq((dst, w))

      GraphMap.putVertex(src, sNeighbors)
      afs.add(src)

      if (!config.directed) {
        dNeighbors ++= Seq((src, w))
        afs.add(dst)
        GraphMap.putVertex(dst, dNeighbors)
      }
    }

    var numSccs = 0
    var numOtherVertices = 0
    var biggestScc = Seq.empty[Int]

    if (config.countSccs) {
      val sccResult = DatasetCleaner.getBiggestSccAndCounts()
      val components = sccResult._1
      biggestScc = components(sccResult._2)
      numSccs = components.size
      val totalVertices = components.foldLeft(0) { (acc, c) => acc + c.size }
      numOtherVertices = totalVertices - biggestScc.size
    }

    return (afs, (numSccs, numOtherVertices, biggestScc))
  }

  def streamingAddAndRun(afs: mutable.HashSet[Int], paths: ParSeq[(Int, Int, Int, Seq[Int])]):
  (ParSeq[(Int, Int, Int, Seq[Int])], Int, Int, Long) = {

    val result = config.rrType match {
      case RrType.m1 => {
        val sTime = System.currentTimeMillis()

        val init = rwalk.createWalkersByVertices(GraphMap.getVertices().par)
        val p = rwalk.secondOrderWalk(init)

        val tTime = System.currentTimeMillis() - sTime

        val ns = computeNumSteps(init)
        val nw = init.length

        (p.map { case (_, w) => (w._1, w._2, 1, w._3) }, ns, nw, tTime)
      }
      case RrType.m2 => {
        val sTime = System.currentTimeMillis()

        val walkers = WalkStorage.filterAffectedPathsForM2(afs, config)
        val partialPaths = rwalk.secondOrderWalk(walkers)
        WalkStorage.updatePaths(partialPaths)

        val tTime = System.currentTimeMillis() - sTime

        val ns = computeNumSteps(walkers)
        val nw = walkers.length

        val newPathIds = partialPaths.map(_._1).toSet
        val allWalks = WalkStorage.getPaths().asScala.toSeq.par.map { case (wId, w) =>
          var isNew = 0
          if (newPathIds.contains(wId))
            isNew = 1
          (w._1, w._2, isNew, w._3)
        }
        (allWalks, ns, nw, tTime)
      }
      case RrType.m3 => {
        val sTime = System.currentTimeMillis()
        val walkers = WalkStorage.filterAffectedPathsForM3(afs, config)
        val partialPaths = rwalk.secondOrderWalk(walkers)
        WalkStorage.updatePaths(partialPaths)

        val tTime = System.currentTimeMillis() - sTime

        val ns = computeNumSteps(walkers)
        val nw = walkers.length
        val newPathIds = partialPaths.map(_._1).toSet
        val allWalks = WalkStorage.getPaths().asScala.toSeq.par.map { case (wId, w) =>
          var isNew = 0
          if (newPathIds.contains(wId))
            isNew = 1
          (w._1, w._2, isNew, w._3)
        }
        (allWalks, ns, nw, tTime)
      }
      case RrType.m4 => {
        val sTime = System.currentTimeMillis()

        var fWalkers: ParSeq[(Int, (Int, Int, Seq[Int]))] = paths.filter(a => afs.contains(a._4
          .head)).map(_._4.head).distinct.map(a => (a, (1, 0, Seq(a))))

        for (a <- afs) {
          if (fWalkers.count(_._1 == a) == 0) {
            fWalkers ++= ParSeq((a, (1, 0, Seq(a))))
          }
        }
        val walkers: ParSeq[(Int, (Int, Int, Seq[Int]))] = ParSeq.fill(config.numWalks)(fWalkers)
          .flatten
        val newWalks = rwalk.secondOrderWalk(walkers)

        val oldWalks = paths.filter { case p =>
          !afs.contains(p._4.head)
        }

        val tTime = System.currentTimeMillis() - sTime

        val allWalks = oldWalks.map { case w => (w._1, w._2, 0, w._4) }.union(newWalks.map { case
          (_, w) => (w._1, w._2, 1, w._3)
        })

        val ns = computeNumSteps(walkers)
        val nw = walkers.length
        (allWalks, ns, nw, tTime)
      }
    }

    result
  }

  def computeNumSteps(walkers: ParSeq[(Int, (Int, Int, Seq[Int]))]) = {
    println("%%%%% Computing number of steps %%%%%")
    val bcWalkLength = config.walkLength + 1
    walkers.map {
      case (_, path) => bcWalkLength - path._3.length
    }.reduce(_ + _)
  }

}
