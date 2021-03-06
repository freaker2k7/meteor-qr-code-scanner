qrReactiveDict = new ReactiveDict

@qrScanner =
	message: -> qrReactiveDict.get 'message'

	on: (eventName, callback) ->
		@[eventName] = callback

	off: (eventName) ->
		delete @[eventName]

	imageData: -> ctx.getImageData(0, 0, w, h)

	imageDataURL: -> $canvas[0].toDataURL("image/jpeg")

	isStarted: -> return started

	isSupported: -> return support

	stopCapture: -> stopCapture()

$canvas = null
$video = null
ctx = null
w = null
h = null
localMediaStream = null
localMediaInterval = null
started = false
support = false

showingCanvas = false

Template._qrScanner.rendered = ->
	showingCanvas = true
	@data?= {}
	w = @data.w?= 320
	h = @data.h?= 240
	$canvas = $('#qr-canvas')
	$video = $('#qr-scanner-video')[0]
	load()

Template._qrScanner.destroyed = ->
	stopCapture()

stopCapture = ->
	if localMediaStream
		try
			localMediaStream.stop()
			localMediaStream.active = false
	if localMediaInterval
		Meteor.clearInterval localMediaInterval
	showingCanvas = false
	qrReactiveDict.set 'message', null
	qrScanner.off 'scan'

isCanvasSupported = ->
	elem = document.createElement("canvas")
	!!(elem.getContext and elem.getContext("2d"))

load = ->
	if isCanvasSupported()
		initDom()
		initWebcam()
	else
		err = 'Your browser does not support canvas'
		console.log err

initDom = ->
	$canvas.width(w).attr('width', w)
	$canvas.height(h).attr('height', h)
	ctx = $canvas[0].getContext("2d")
	ctx.clearRect 0, 0, w, h
	return

initWebcam = ->
	navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia
	started = true
	if navigator.getUserMedia
		optional_source = []
		MediaStreamTrack.getSources (sourceInfos) ->
			for i in [0..sourceInfos.length]
				sourceInfo = sourceInfos[i]
				if sourceInfo.kind == 'video' && (sourceInfo.facing == '' || sourceInfo.facing == 'environment')
					optional_source = [sourceId: sourceInfo.id]
					break

			navigator.getUserMedia
				video:
					mandatory:
						maxWidth: w
						maxHeight: h
					optional: optional_source
				audio: false
			, (stream) ->
				if navigator.webkitGetUserMedia
					$video.src = window.URL.createObjectURL(stream)
				else if navigator.mozGetUserMedia
					$video.mozSrcObject = stream
					$video.play()
				else
					$video.src = stream
				localMediaStream = stream
				if !localMediaInterval
					localMediaInterval = Meteor.setInterval captureToCanvas, 250
			, (err) ->
				console.log err
	else
		support = false
		console.log 'Your borwser doesnt support getUserMedia'

captureToCanvas = ->
	ctx.drawImage $video, 0, 0
	try
		message = qrcode.decode()
		qrReactiveDict.set 'message', message
		if qrScanner.scan then qrScanner.scan null, message
	catch
		err = "The QR code isnt visible or couldn't be read"
		if qrScanner.scan then qrScanner.scan err, null