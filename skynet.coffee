#!/usr/bin/env coffee

sys = require 'util'
util = require 'util'
xmpp = require 'node-xmpp'
account = require './account'
commands = require('./commands')

parseCommand = (message) ->
  parts = message.split(' ')
  return {
    command: parts[0]?.trim()
    args: parts[1..]
  }

processMessage = (message, comms) ->
  mParts = parseCommand(message)

  # if a command exists, run it
  commands.commands[mParts.command]?.run(comms, mParts.args)

  # run all inspections on message body
  for i of commands.inspections
    i = commands.inspections[i]
    if i.match(message)
      try
        i.run(comms, message)
      catch error
        util.log "Error: #{ error }"

class Comms
  constructor: (roomId, @sender) ->
    @setRoom(roomId)

  setRoom: (roomId) ->
    @room = roomId + '/' + account.roomNick

  send: (message) ->
    util.log "Sending: " + message
    if @sender?
      util.log "Sending reply to: " + @sender
      to = @sender
      type = 'chat'
    else
      to = @room
      type = 'groupchat'

    cl.send(new xmpp.Element('message',
        {
          to: to,
          type: type
        }
      ).
      c('body').
      t(message)
    )

cl = new xmpp.Client
  jid: account.jabberId + '/bot'
  password: account.password
      
cl.on 'online', ->
  util.log("Skynet Online")

  cl.send(new xmpp.Element('presence', { type: 'available' }).
    c('show').t('chat')
  )

  for room in account.roomJids
    do (room) ->
      util.log("Connecting to " + room)
      announcePresence = ->
        cl.send(new xmpp.Element('presence', {
            to: room + '/' + account.roomNick
          }).
          c('x', { xmlns: 'http://jabber.org/protocol/muc' })
        )
      announcePresence()
      setInterval(announcePresence, 30000)

cl.on 'stanza', (stanza) ->
  if stanza.attrs?.type is 'error'
    util.log '[error]' + stanza
    return

  # ignore everything that isn't a room message
  if not stanza.is('message')
    return

  # ignore messages we sent
  if stanza.attrs.from.indexOf(account.roomNick) isnt -1
    return

  sender = null
  if stanza.attrs?.type is 'chat'
    sender = stanza.attrs.from
  else if stanza.attrs?.type is 'groupchat'
    sender = null
  else
    return

  comms = new Comms(stanza.attrs.from.split('/')[0], sender)

  body = stanza.getChild 'body'
  # ignore messages without a body
  if not body
    return

  message = body.getText()

  processMessage(message, comms)


exports.processMessage = processMessage
