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
  property var contacts: undefined
  property var ratings: undefined

  property int localAppStarts: 0
  property bool feedBackSent: false

  property string timeZone: "+0200"

  property var webStorage: undefined // reference to WebStorage for favorites
  readonly property bool loading: _.loadingCount > 0
  readonly property bool loaded: !!schedule && !!speakers

  property bool initialized: false
  onInitializedChanged: loadData() // load/update data after initialization

  property bool notificationsEnabled: true
  onNotificationsEnabledChanged: storage.setValue("notificationsEnabled", notificationsEnabled)

  signal loadingFailed()
  signal favoriteAdded(var talk)
  signal favoriteRemoved(var talk)

  // item for private members
  QtObject {
    id: _

    // qtws 2017 api urls
    property string qtwsApiScheduleUrl: Qt.resolvedUrl("https://www.qtworldsummit.com/api/schedule/all/")
    property string qtwsApiSpeakersUrl: Qt.resolvedUrl("https://www.qtworldsummit.com/api/speakers/all/")
    property string qtwsApiVersionUrl: Qt.resolvedUrl("https://www.qtworldsummit.com/api/version/show/")

    // fallback urls of locally stored version in assets
    property string fallbackScheduleUrl: Qt.resolvedUrl("../../assets/data/schedule.json")
    property string fallbackSpeakersUrl: Qt.resolvedUrl("../../assets/data/speakers.json")
    property string fallbackVersionUrl: Qt.resolvedUrl("../../assets/data/version.json")


    property int loadingCount: 0

    // sendGetRequest - load data from url with success handler
    function sendGetRequest(url, successHandler, errorHandler) {
      var xmlHttpReq = new XMLHttpRequest()
      xmlHttpReq.onreadystatechange = function() {
        if(xmlHttpReq.readyState == xmlHttpReq.DONE && xmlHttpReq.status == 200) {
          var fixedResponse = xmlHttpReq.responseText.replace(new RegExp("&amp;",'g'),"&")
          successHandler(JSON.parse(fixedResponse))
          loadingCount--
        }
        else if(xmlHttpReq.readyState == xmlHttpReq.DONE && xmlHttpReq.status != 200) {
          console.error("Error: Failed to load data from "+url+", status = "+xmlHttpReq.status+", response = "+XMLHttpRequest.responseText)
          loadingCount--
          if(errorHandler !== undefined)
            errorHandler()
          else if(!loading)
            dataModel.loadingFailed()
        }
      }

      loadingCount++
      xmlHttpReq.open("GET", url, true)
      xmlHttpReq.send()
    }

    // checkAPIVersion - checks Qt WS API version and updates data if necessary
    function checkAPIVersion(useLocalData) {
      var versionUrl = useLocalData ? _.fallbackVersionUrl : _.qtwsApiVersionUrl

      _.sendGetRequest(versionUrl, function(data) {
        var currVersion = data.version

        // load new data when debug build, first call, or newer version available
        if(!system.publishBuild || dataModel.version === undefined || dataModel.version !== currVersion) {
          dataModel.version = currVersion
          _.loadSchedule(useLocalData) // also loads speakers
        }
      }, function() {
        // custom error handler
        if(dataModel.version === undefined && useLocalData === undefined)
          checkAPIVersion(true)
        else if(!loading)
          dataModel.loadingFailed()
      })
    }

    // loadSchedule - load Qt WS schedule from api
    function loadSchedule(useLocalData) {
      var scheduleUrl = useLocalData ? _.fallbackScheduleUrl : _.qtwsApiScheduleUrl

      _.sendGetRequest(scheduleUrl, function(data) {
        _.processScheduleData(data)
        // load speakers after schedule is processed
        _.loadSpeakers(useLocalData)
      })
    }

    // loadSpeakers - load Qt WS speakers from api
    function loadSpeakers(useLocalData) {
      var speakersUrl = useLocalData ? _.fallbackSpeakersUrl : _.qtwsApiSpeakersUrl

      _.sendGetRequest(speakersUrl, function(data) {
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
            if(end[1] >= 60) {
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
    dataModel.ratings = storage.getValue("ratings")
    dataModel.notificationsEnabled = storage.getValue("notificationsEnabled") !== undefined ? storage.getValue("notificationsEnabled") : true

    dataModel.localAppStarts = storage.getValue("localAppStarts") || 0
    dataModel.feedBackSent = storage.getValue("feedBackSent") || false

    // get favorites and contacts from web storage
    dataModel.webStorage = webStorageItem
    dataModel.favorites = webStorage.getValue("favorites")
    dataModel.contacts = webStorage.getValue("contacts")

    dataModel.initialized = true
  }

  // reset DataModel
  function reset() {
    dataModel.initialized = false
    dataModel.version = undefined
    dataModel.schedule = undefined
    dataModel.speakers = undefined
    dataModel.tracks = undefined
    dataModel.talks = undefined
    dataModel.ratings = undefined
    dataModel.favorites = undefined
    dataModel.contacts = undefined
    dataModel.notificationsEnabled = true

    localAppStarts = 0
    feedBackSent = false
  }

  // clearCache - clears locally stored data
  function clearCache() {
    // reset dataModel, but keep favorites and contacts
    var favorites = dataModel.favorites
    var contacts = dataModel.contacts
    dataModel.reset()
    dataModel.favorites = favorites
    dataModel.contacts = contacts

    // clear local storage, favorites and contacts are still in webStorage
    storage.clearAll()
    initialized = true // also reloads api data after reset
  }

  // loadData - loads all data from Qt WS 2017 api
  function loadData() {
    if(initialized && !loading) {
      _.checkAPIVersion() // checks version and loads data if necessary
    }
  }

  // loadContact - loads contact from Eventbrite
  function loadContact(id, successHandler, errorHandler) {
    _.sendGetRequest(Qt.resolvedUrl("https://www.qtworldsummit.com/api/attendee/show/?id="+id), successHandler, errorHandler)
  }

  // toggleFavorite - add or remove item from favorites
  function toggleFavorite(item) {
    if(dataModel.favorites === undefined)
      dataModel.favorites = { }

    if(dataModel.favorites[item.id]) {
      delete dataModel.favorites[item.id]
      dataModel.favoriteRemoved(item)
    }
    else {
      dataModel.favorites[item.id] = item.id
      dataModel.favoriteAdded(item)
    }

    // store favorites
    webStorage.setValue("favorites", dataModel.favorites, function(data) {
      // in case setValue merges favorites with data from server, we update the local value
      // the merged server data comes as stringified string, thus call json.parse here
      //dataModel.favorites = webStorage.getValue("favorites") // no need to call getValue() again, we get the value from the callback
      console.debug("server favorites data:", JSON.stringify(data))
      // only update the local favorites, if the server has new merged data, in this case conflict is true
      if(data["conflict"]) {
        dataModel.favorites = data.mergedData
      }

    })
    // call the changed here, to schedule the notifications with the new local data
    favoritesChanged()
  }

  // isFavorite - check if item is favorited
  function isFavorite(id) {
    return dataModel.favorites !== undefined && dataModel.favorites[id] !== undefined
  }

  // addContact - store contact from barcode scanner
  function addContact(id, contact) {
    if(dataModel.contacts === undefined)
      dataModel.contacts = { }

    // store contact
    dataModel.contacts[id] = contact
    webStorage.setValue("contacts", dataModel.contacts, function(data) {
      // in case setValue merges contacts with data from server, we update the local value
      // only update the local favorites, if the server has new merged data, in this case conflict is true
      if(data["conflict"]) {
        dataModel.contacts = data.mergedData
      }
    })

    // signal that contacts changed
    dataModel.contactsChanged()
  }

  // removeContact - remove contact from list
  function removeContact(id) {
    if(dataModel.contacts !== undefined && dataModel.contacts[id]) {
      delete dataModel.contacts[id]

      // store contacts
      webStorage.setValue("contacts", dataModel.contacts, function(data) {
        // in case setValue merges contacts with data from server, we update the local value
        // only update the local favorites, if the server has new merged data, in this case conflict is true
        if(data["conflict"]) {
          dataModel.contacts = data.mergedData
        }
      })

      // signal that contacts changed
      dataModel.contactsChanged()
    }
  }

  function getRating(id) {
    if(!ratings || !(id in ratings)) return -1
    else return ratings[id]
  }

  function storeRating(id, rating) {
    if(!ratings) ratings = {}
    ratings[id] = rating
    storage.setValue("ratings", ratings)
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

  // increase local app start counter
  function increaseLocalAppStarts() {
    if(!initialized)
      return

    localAppStarts++
    storage.setValue("localAppStarts",localAppStarts)
  }

  // store whether feedback was sent
  function setFeedBackSent(value) {
    if(!initialized)
      return

    feedBackSent = !!value  // ensures boolean type
    storage.setValue("feedBackSent", feedBackSent)
  }
}
