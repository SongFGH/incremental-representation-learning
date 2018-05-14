package au.csiro.data61.randomwalk.common

import org.scalatest.FunSuite


/**
  * Created by Hooman on 2018-02-27.
  */
class DatasetCleanerTest extends FunSuite {

  private val dataset = "/Users/Ganymedian/Desktop/Projects/stellar-random-walk-research/data/cora/"

  test("testCheckDataSet") {
    val fName = dataset + "cora_edgelist.txt"
    val initId = 0
    val config = Params(input = fName, delimiter = "\\s+", directed = true)
    DatasetCleaner.checkDataSet(config, initId)

  }

  case class CoAuthor(a1: String, a2: String, year: Int)

  test("jsonConvertor") {
    val fName = dataset + "test.json"
    val output = dataset
    val config = Params(input = fName, output = output)
    DatasetCleaner.convertJsonFile(config)

  }

}
