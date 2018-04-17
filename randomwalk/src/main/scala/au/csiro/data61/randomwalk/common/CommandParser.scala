package au.csiro.data61.randomwalk.common

import scopt.OptionParser

object CommandParser {

  object TaskName extends Enumeration {
    type TaskName = Value
    val firstorder, secondorder, soProbs, queryPaths, probs, degrees, affecteds, passProbs, rr,
    ar, s1, coAuthors, sca, ae, gPairs =
      Value
  }

  object WalkType extends Enumeration {
    type WalkType = Value
    val firstorder, secondorder = Value
  }

  object RrType extends Enumeration {
    type RrType = Value
    val m1, m2, m3, m4 = Value
  }

  val WALK_LENGTH = "walkLength"
  val NUM_WALKS = "numWalks"
  val RDD_PARTITIONS = "rddPartitions"
  val WEIGHTED = "weighted"
  val DIRECTED = "directed"
  val WALK_TYPE = "wType"
  val NUM_RUNS = "nRuns"
  val RR_TYPE = "rrType"
  val P = "p"
  val Q = "q"
  val AL = "al"
  val INPUT = "input"
  val OUTPUT = "output"
  val CMD = "cmd"
  val NODE_IDS = "nodes"
  val NUM_VERTICES = "nVertices"
  val SEED = "seed"
  val DELIMITER = "d"
  val W2V_WINDOW = "w2vWindow"
  val W2V_SKIP_SIZE = "w2vSkip"
  val SAVE_PERIOD = "save"
  val LOG_ERRORS = "logErrors"
  val INIT_EDGE_Size = "initEdgeSize"
  val EDGE_STREAM_Size = "edgeStreamSize"
  val MAX_STEPS = "maxSteps"

  private lazy val defaultParams = Params()
  private lazy val parser = new OptionParser[Params]("2nd Order Random Walk + Word2Vec") {
    head("Main")
    opt[Int](WALK_LENGTH)
      .text(s"walkLength: ${defaultParams.walkLength}")
      .action((x, c) => c.copy(walkLength = x))
    opt[Int](NUM_WALKS)
      .text(s"numWalks: ${defaultParams.numWalks}")
      .action((x, c) => c.copy(numWalks = x))
    opt[Int](NUM_RUNS)
      .text(s"numWalks: ${defaultParams.numRuns}")
      .action((x, c) => c.copy(numRuns = x))
    opt[Double](P)
      .text(s"numWalks: ${defaultParams.p}")
      .action((x, c) => c.copy(p = x.toFloat))
    opt[Double](Q)
      .text(s"numWalks: ${defaultParams.q}")
      .action((x, c) => c.copy(q = x.toFloat))
    opt[Double](INIT_EDGE_Size)
      .text(s"Percentage of edges to be used to construct the initial graph before streaming: ${defaultParams.initEdgeSize}")
      .action((x, c) => c.copy(initEdgeSize = x.toFloat))
    opt[Double](EDGE_STREAM_Size)
      .text(s"Percentage of edges to stream at every step: ${defaultParams.edgeStreamSize}")
      .action((x, c) => c.copy(edgeStreamSize = x.toFloat))
    opt[Int](NUM_VERTICES)
      .text(s"numWalks: ${defaultParams.numVertices}")
      .action((x, c) => c.copy(numVertices = x))
    opt[Int](AL)
      .text(s"numWalks: ${defaultParams.affectedLength}")
      .action((x, c) => c.copy(affectedLength = x))
    opt[Int](SAVE_PERIOD)
      .text(s"Save Period: ${defaultParams.savePeriod}")
      .action((x, c) => c.copy(savePeriod = x))
    opt[Int](MAX_STEPS)
      .text(s"Max number of steps to run experiments: ${defaultParams.maxSteps}")
      .action((x, c) => c.copy(maxSteps = x))
    opt[Int](W2V_WINDOW)
      .text(s"Word2Vec window size: ${defaultParams.w2vWindow}")
      .action((x, c) => c.copy(w2vWindow = x))
    opt[Int](W2V_SKIP_SIZE)
      .text(s"Word2Vec skip size: ${defaultParams.w2vSkipSize}")
      .action((x, c) => c.copy(w2vSkipSize = x))
    opt[Long](SEED)
      .text(s"seed: ${defaultParams.seed}")
      .action((x, c) => c.copy(seed = x))
    opt[Boolean](WEIGHTED)
      .text(s"weighted: ${defaultParams.weighted}")
      .action((x, c) => c.copy(weighted = x))
    opt[Boolean](DIRECTED)
      .text(s"directed: ${defaultParams.directed}")
      .action((x, c) => c.copy(directed = x))
    opt[Boolean](LOG_ERRORS)
      .text(s"Log Errors (increases run time): ${defaultParams.logErrors}")
      .action((x, c) => c.copy(logErrors = x))
    opt[String](INPUT)
      .required()
      .text("Input edge file path: empty")
      .action((x, c) => c.copy(input = x))
    opt[String](DELIMITER)
      .text("Delimiter: ")
      .action((x, c) => c.copy(delimiter = x))
    opt[String](OUTPUT)
      .required()
      .text("Output path: empty")
      .action((x, c) => c.copy(output = x))
    opt[String](NODE_IDS)
      .text("Node IDs to query from the paths: empty")
      .action((x, c) => c.copy(nodes = x))
    opt[String](CMD)
      .required()
      .text(s"command: ${defaultParams.cmd.toString}")
      .action((x, c) => c.copy(cmd = TaskName.withName(x)))
    opt[String](RR_TYPE)
      .text(s"RR Type: ${defaultParams.rrType.toString}")
      .action((x, c) => c.copy(rrType = RrType.withName(x)))
    opt[String](WALK_TYPE)
      .text(s"Walk Type: ${defaultParams.wType.toString}")
      .action((x, c) => c.copy(wType = WalkType.withName(x)))
  }

  def parse(args: Array[String]) = {
    parser.parse(args, defaultParams)
  }
}
