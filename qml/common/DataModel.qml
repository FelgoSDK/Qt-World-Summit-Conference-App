pragma Singleton
import VPlayApps 1.0
import VPlay 2.0
import QtQuick 2.0

Item {
  id: dataModel

  // stored data
  property var version: undefined
  property var schedule: undefined
  property var speakers: undefined
  property var tracks: undefined
  property var favorites: undefined
  property var talks: undefined
  property string timeZone: "+0200"

  property var webStorage: undefined // reference to WebStorage for favorites
  readonly property bool loading: _.loadingCount > 0
  readonly property bool loaded: !!schedule && !!speakers

  property bool initialized: false
  onInitializedChanged: loadData() // load/update data after initialization

  property bool notificationsEnabled: true
  onNotificationsEnabledChanged: storage.setValue("notificationsEnabled", notificationsEnabled)

  signal loadingFailed()
  signal favoriteAdded()
  signal favoriteRemoved()

  // item for private members
  QtObject {
    id: _

    // qtws 2017 api urls
    property string qtwsApiScheduleUrl: Qt.resolvedUrl("https://www.qtworldsummit.com/api/schedule/all/") //Qt.resolvedUrl("../../assets/data/schedule.json")
    property string qtwsApiSpeakersUrl: Qt.resolvedUrl("https://www.qtworldsummit.com/api/speakers/all/") //Qt.resolvedUrl("../../assets/data/speakers.json")
    property string qtwsApiVersionUrl: Qt.resolvedUrl("https://www.qtworldsummit.com/api/version/show/")

    property int loadingCount: 0

    // sendGetRequest - load data from url with success handler
    function sendGetRequest(url, success) {
      var xmlHttpReq = new XMLHttpRequest()
      xmlHttpReq.onreadystatechange = function() {
        if(xmlHttpReq.readyState == xmlHttpReq.DONE && xmlHttpReq.status == 200) {
          var fixedResponse = xmlHttpReq.responseText.replace(new RegExp("&amp;",'g'),"&")
          success(JSON.parse(fixedResponse))
          loadingCount--
        }
        else if(xmlHttpReq.readyState == xmlHttpReq.DONE && xmlHttpReq.status != 200) {
          console.error("Error: Failed to load data from "+url+", status = "+xmlHttpReq.status+", response = "+XMLHttpRequest.responseText)
          loadingCount--
          if(!loading)
            dataModel.loadingFailed()
        }
      }

      loadingCount++
      xmlHttpReq.open("GET", url, true)
      xmlHttpReq.send()
    }

    // checkAPIVersion - checks Qt WS API version and updates data if necessary
    function checkAPIVersion() {
      _.sendGetRequest(_.qtwsApiVersionUrl, function(data) {
        var currVersion = data.version.substr(2) // e.g. version 1.2345 -> 2345, required because e.g. 1.92 should be lower than 1.715

        // load new data when debug build, first call, or newer version available
        if(system.publishBuild || dataModel.version === undefined || dataModel.version < currVersion) {
          dataModel.version = currVersion
          _.loadSchedule() // also loads speakers
        }
      })
    }

    // loadSchedule - load Qt WS schedule from api
    function loadSchedule() {
      _.sendGetRequest(_.qtwsApiScheduleUrl, function(data) {
        _.processScheduleData(data)
        // load speakers after schedule is processed
        _.loadSpeakers()
      })
    }

    // loadSpeakers - load Qt WS speakers from api
    function loadSpeakers() {
      _.sendGetRequest(_.qtwsApiSpeakersUrl, function(data) {
        _.processSpeakersData(data)

        // when schedule and speakers are loaded, all loading is done -> cache current API version
        storage.setValue("version", dataModel.version)
      })
    }

    // processScheduleData - process schedule data for usage in UI
    function processScheduleData(data) {
      // retrieve tracks and talks and build model for tracks, talks and schedule
      var tracks = {}
      var talks = {}
      for(var day in data.conference.days) {
        for(var room in data.conference.days[day]["rooms"])
          for (var eventIdx in data.conference.days[day]["rooms"][room]) {
            var event = data.conference.days[day]["rooms"][room][eventIdx]

            // calculate event end time
            var start = event.start.split(":")
            var duration = event.duration.split(":")
            var end = [parseInt(start[0])+parseInt(duration[0]),
                       parseInt(start[1])+parseInt(duration[1])]
            if(end[1] > 60) {
              end[1] -= 60
              end[0] += 1
            }

            // format start and end time
            event.start = _.format2DigitTime(start[0]) + ":" + _.format2DigitTime(start[1])
            event.end = _.format2DigitTime(end[0]) + ":" + _.format2DigitTime(end[1])

            // clean-up false start time formatting (always 2 digits required)
            if(event.start.substring(1,2) == ':') {
              event.start = "0"+event.start
            }

            // add day of event (for favorites)
            event.day = day

            // build tracks model
            if(event["tracks"] !== undefined && Array.isArray(event["tracks"])) {
              for(var idx in event["tracks"])
                tracks[event["tracks"][idx]] = 0
            }

            // clean up incorrect room entries of API version 1.953
            if(event["room"] == "Berlin" || event["room"] == ":")
              event["room"] = ""

            // build talks model
            talks[event["id"]] = event

            // replace talks in schedule with talk-id
            data.conference.days[day]["rooms"][room][eventIdx] = event["id"]
          }
      }

      //  define track colors
      var hueDiff = 1 / Object.keys(tracks).length
      var i = 0
      for(var track in tracks) {
        tracks[track] = i * hueDiff
        i++
      }

      // store data
      dataModel.talks = talks
      dataModel.tracks = tracks
      dataModel.schedule = data
      storage.setValue("talks", talks)
      storage.setValue("tracks", tracks)
      storage.setValue("schedule", data)

      // force update of favorites as new data arrived
      var favorites = dataModel.favorites
      dataModel.favorites = undefined
      dataModel.favorites = favorites
    }

    // processSpeakersData - process schedule data for usage in UI
    function processSpeakersData(data) {
      // convert speaker data into model map with id as key
      var speakers = {}
      for(var i = 0; i < data.length; i++) {
        var speaker = data[i]
        speakers[speaker.id] = speaker

        var talks= []
        for (var j in Object.keys(dataModel.talks)) {
          var talkID = Object.keys(dataModel.talks)[j];
          var talk = dataModel.talks[parseInt(talkID)]
          var persons = talk.persons

          for(var k in persons) {
            if(persons[k].id === speaker.id) {
              talks.push(talkID.toString())
            }
          }
        }
        speakers[speaker.id]["talks"] = talks
      }
      // store data
      dataModel.speakers = speakers
      storage.setValue("speakers", speakers)
    }

    // format2DigitTime - adds leading zero to time (hour, minute) if required
    function format2DigitTime(time) {
      return (("" + time).length < 2) ? "0" + time : time
    }
  }

  // storage for caching data
  Storage {
    id: storage
    databaseName: "localStorage"
  }

  // initialize - initialize data from storages
  function initialize(webStorageItem) {
    // get data from local storage
    dataModel.version = storage.getValue("version")
    dataModel.schedule = storage.getValue("schedule")
    dataModel.speakers = storage.getValue("speakers")
    dataModel.tracks = storage.getValue("tracks")
    dataModel.talks = storage.getValue("talks")
    dataModel.notificationsEnabled = storage.getValue("notificationsEnabled") !== undefined ? storage.getValue("notificationsEnabled") : true

    // get favorites from web storage
    dataModel.webStorage = webStorageItem
    dataModel.favorites = webStorage.getValue("favorites")

    dataModel.initialized = true
  }

  // reset DataModel, required when e.g. GameNetwork user changes
  function reset() {
    dataModel.initialized = false
    dataModel.version = undefined
    dataModel.schedule = undefined
    dataModel.speakers = undefined
    dataModel.tracks = undefined
    dataModel.talks = undefined
    dataModel.favorites = undefined
    dataModel.notificationsEnabled = true
  }

  // clearCache - clears locally stored data
  function clearCache() {
    // reset dataModel, but keep favorites
    var favorites = dataModel.favorites
    dataModel.reset()
    dataModel.favorites = favorites

    // clear local storage, favorites are still in webStorage
    storage.clearAll()
    initialized = true // also reloads api data after reset
  }

  // loadData - loads all data from Qt WS 2017 api
  function loadData() {
    if(initialized && !loading) {
      _.checkAPIVersion() // checks version and loads data if necessary
    }
  }

  // toggleFavorite - add or remove item from favorites
  function toggleFavorite(item) {
    if(dataModel.favorites === undefined)
      dataModel.favorites = { }

    if(dataModel.favorites[item.id]) {
      delete dataModel.favorites[item.id]
      dataModel.favoriteRemoved()
    }
    else {
      dataModel.favorites[item.id] = item.id
      dataModel.favoriteAdded()
    }

    // store favorites
    webStorage.setValue("favorites", dataModel.favorites, function(data) {
      // in case setValue merges favorites with data from server, we update the local value
      dataModel.favorites = webStorage.getValue("favorites")
    })
    favoritesChanged()
  }

  // isFavorite - check if item is favorited
  function isFavorite(id) {
    return dataModel.favorites !== undefined && dataModel.favorites[id] !== undefined
  }

  // search - get talks with certain keyword in title or description
  function search(query) {
    if(!dataModel.talks)
      return []

    query = query.toLowerCase().split(" ")
    var result = []

    // check talks
    for(var id in talks) {
      var talk = talks[id]
      var contains = 0

      // check query
      for (var key in query) {
        var term = query[key].trim()
        if(talk.title.toLowerCase().indexOf(term) >= 0 ||
            talk.description.toLowerCase().indexOf(term) >= 0) {
          contains++
        }
        for(var key2 in talk.persons) {
          var speaker = talk.persons[key2]
          if(speaker.full_public_name.toLowerCase().indexOf(term) >= 0) {
            contains++
          }
        }
      }

      if(contains == query.length)
        result.push(talk)
    } // check talks

    return result
  }

  // prepareTracks - prepare track data for display in TracksPage
  function prepareTracks(tracks) {
    if(!dataModel.talks)
      return []

    var model = []
    for(var i in Object.keys(tracks)){
      var track = Object.keys(tracks)[i];
      var talks = []

      for(var j in Object.keys(dataModel.talks)) {
        var talkID = Object.keys(dataModel.talks)[j]
        var talk = dataModel.talks[parseInt(talkID)]

        if(talk !== undefined && talk.tracks.indexOf(track) > -1) {
          talks.push(talk)
        }
      }
      talks = prepareTrackTalks(talks)
      model.push({"title" : track, "talks" : talks})
    }
    model.sort(compareTitle)

    return model
  }

  // prepareTrackTalks - package talk data in array ready to be displayed by TimeTableDaySchedule item
  function prepareTrackTalks(trackTalks) {
    if(!trackTalks)
      return []

    var days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];

    // get events and prepare data for sorting and sections
    for(var idx in trackTalks) {
      var data = trackTalks[idx]

      // prepare event date for sorting
      var date = new Date(data.day)
      data.dayTime = date.getTime()

      // prepare event section
      var weekday = isNaN(date.getTime()) ? "Unknown" : days[ date.getDay() ]
      data.section = weekday + ", " + (data.start.substring(0, 2) + ":00")

      trackTalks[idx] = data
    }

    // sort events
    trackTalks = trackTalks.sort(function(a, b) {
      if(a.dayTime == b.dayTime)
        return (a.start > b.start) - (a.start < b.start)
      else
        return (a.dayTime > b.dayTime) - (a.dayTime < b.dayTime)
    })

    return trackTalks
  }

  // sort tracks by title
  function compareTitle(a,b) {
    if (a.title < b.title)
      return -1;
    if (a.title > b.title)
      return 1;
    return 0;
  }
}
