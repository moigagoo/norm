import unittest

import os, strutils, sequtils, times

import norm / mongodb


const
  # for local testing, modify your /etc/hosts file to contain "mongodb_1"
  # pointing to your local mongodb server
  dbConnection = "mongodb://mongodb_1:27017"
  dbName = "TestDb"
  customDbName = "TestCustomDb"

type
  LittleMix = object
    af: seq[float]
    nt: Option[Time]

db(dbConnection, "", "", dbName):
  type
    BigMix = object
      name: string
      ab: seq[bool]
      af: seq[float]
      ai: seq[int]
      ao: seq[Oid]
      xas: seq[string]
      at: seq[Time]
      nb: Option[bool]
      nf: Option[float]
      ni: Option[int]
      no: Option[Oid]
      ns: Option[string]
      nt: Option[Time]
      ant: seq[Option[Time]]
      anb: seq[Option[bool]]
      anf: seq[Option[float]]
      ani: seq[Option[int]]
      ano: seq[Option[Oid]]
      ans: seq[Option[string]]
      xant: seq[Option[Time]]
      nab: Option[seq[bool]]
      naf: Option[seq[float]]
      nai: Option[seq[int]]
      nao: Option[seq[Oid]]
      nas: Option[seq[string]]
      nat: Option[seq[Time]]
      nanb: Option[seq[Option[bool]]]
      nanf: Option[seq[Option[float]]]
      nani: Option[seq[Option[int]]]
      nano: Option[seq[Option[Oid]]]
      nans: Option[seq[Option[string]]]
      nant: Option[seq[Option[Time]]]

const
  REFOID = "012345678901234567890123"
  REFTIME = "2018-03-25T12:00:12"
  TIMEFMT = "yyyy-MM-dd\'T\'HH:mm:ss"

suite "Inserting field structures":
  setup:
    withDb:
      createTables(force=true)

      var clean = BigMix(
        name: "clean",
        ab: @[true, false, true],
        af: @[1.2, -3.4, 5.6],
        ai: @[1, -2, 3],
        ao: @[parseOid(REFOID), parseOid(REFOID)],
        xas: @["a", "", "c"],  # "as" is a keyword, so I stuck a x on the front
        at: @[parseTime(REFTIME, TIMEFMT, utc()), parseTime(REFTIME, TIMEFMT, utc())],
        nb: some true,
        nf: some 1.2,
        ni: some 1,
        no: some parseOid(REFOID),
        ns: some "a",
        nt: some parseTime(REFTIME, TIMEFMT, utc()),
        anb: @[some true, some false, some true],
        anf: @[some 1.2, some -3.4, some 5.6],
        ani: @[some 1, some -2, some 3],
        ano: @[some parseOid(REFOID), some parseOid(REFOID)],
        ans: @[some "a", some "", some "c"],
        xant: @[some parseTime(REFTIME, TIMEFMT, utc()), some parseTime(REFTIME, TIMEFMT, utc())],
        nab: some @[true, false, true],
        naf: some @[1.2, -3.4, 5.6],
        nai: some @[1, -2, 3],
        nao: some @[parseOid(REFOID), parseOid(REFOID)],
        nas: some @["a", "", "c"],
        nat: some @[parseTime(REFTIME, TIMEFMT, utc()), parseTime(REFTIME, TIMEFMT, utc())],
        nanb: some @[some true, some false, some true],
        nanf: some @[some 1.2, some -3.4, some 5.6],
        nani: some @[some 1, some -2, some 3],
        nano: some @[some parseOid(REFOID), some parseOid(REFOID)],
        nans: some @[some "a", some "", some "c"],
        nant: some @[some parseTime(REFTIME, TIMEFMT, utc()), some parseTime(REFTIME, TIMEFMT, utc())]
      )
      clean.insert()

      var nulled = BigMix(
        name: "nulled",
        ab: @[true, false, true],
        af: @[1.2, -3.4, 5.6],
        ai: @[1, -2, 3],
        ao: @[parseOid(REFOID), parseOid(REFOID)],
        xas: @["a", "", "c"],
        at: @[parseTime(REFTIME, TIMEFMT, utc()), parseTime(REFTIME, TIMEFMT, utc())],
        nb: none(bool),
        nf: none(float),
        ni: none(int),
        no: none(Oid),
        ns: none(string),
        nt: none(Time),
        anb: @[none(bool), none(bool), none(bool)],
        anf: @[none(float), none(float), none(float)],
        ani: @[none(int), none(int), none(int)],
        ano: @[none(Oid), none(Oid)],
        ans: @[none(string), none(string), none(string)],
        xant: @[none(Time), none(Time)],
        nab: none(seq[bool]),
        naf: none(seq[float]),
        nai: none(seq[int]),
        nao: none(seq[Oid]),
        nas: none(seq[string]),
        nat: none(seq[Time]),
        nanb: some @[none(bool), none(bool), none(bool)],
        nanf: some @[none(float), none(float), none(float)],
        nani: some @[none(int), none(int), none(int)],
        nano: some @[none(Oid), none(Oid)],
        nans: some @[none(string), none(string), none(string)],
        nant: some @[none(Time), none(Time)],
      )
      nulled.insert()

  # teardown:
  #   withDb:
  #     dropTables()

  test "Reading field structures":
    withDb:
      let
        mixes = BigMix.getMany(100, sort = %*{"name": 1})

      check len(mixes) == 2

      check mixes[0].name == "clean"
      check mixes[0].ab == @[true, false, true]
      check mixes[0].af == @[1.2, -3.4, 5.6]
      check mixes[0].ai == @[1, -2, 3]
      check mixes[0].ao == @[parseOid(REFOID), parseOid(REFOID)]
      check mixes[0].xas == @["a", "", "c"]
      check mixes[0].at == @[parseTime(REFTIME, TIMEFMT, utc()), parseTime(REFTIME, TIMEFMT, utc())]
      check mixes[0].nb == some true
      check mixes[0].nf == some 1.2
      check mixes[0].ni == some 1
      check mixes[0].no == some parseOid(REFOID)
      check mixes[0].ns == some "a"
      check mixes[0].nt == some parseTime(REFTIME, TIMEFMT, utc())
      check mixes[0].anb == @[some true, some false, some true]
      check mixes[0].anf == @[some 1.2, some -3.4, some 5.6]
      check mixes[0].ani == @[some 1, some -2, some 3]
      check mixes[0].ano == @[some parseOid(REFOID), some parseOid(REFOID)]
      check mixes[0].ans == @[some "a", some "", some "c"]
      check mixes[0].xant == @[some parseTime(REFTIME, TIMEFMT, utc()), some parseTime(REFTIME, TIMEFMT, utc())]
      check mixes[0].nab == some @[true, false, true]
      check mixes[0].naf == some @[1.2, -3.4, 5.6]
      check mixes[0].nai == some @[1, -2, 3]
      check mixes[0].nao == some @[parseOid(REFOID), parseOid(REFOID)]
      check mixes[0].nas == some @["a", "", "c"]
      check mixes[0].nat == some @[parseTime(REFTIME, TIMEFMT, utc()), parseTime(REFTIME, TIMEFMT, utc())]
      check mixes[0].nanb == some @[some true, some false, some true]
      check mixes[0].nanf == some @[some 1.2, some -3.4, some 5.6]
      check mixes[0].nani == some @[some 1, some -2, some 3]
      check mixes[0].nano == some @[some parseOid(REFOID), some parseOid(REFOID)]
      check mixes[0].nans == some @[some "a", some "", some "c"]
      check mixes[0].nant == some @[some parseTime(REFTIME, TIMEFMT, utc()), some parseTime(REFTIME, TIMEFMT, utc())]

