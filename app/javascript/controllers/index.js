import { Application } from "@hotwired/stimulus"
import RoomController from "./room_controller"

window.Stimulus = Application.start()
Stimulus.register("room", RoomController)
