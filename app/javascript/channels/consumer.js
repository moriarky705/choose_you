import { createConsumer } from "@rails/actioncable"

// 本番環境では明示的にWebSocket URLを指定
const wsUrl = window.location.hostname.includes('onrender.com') 
  ? `wss://${window.location.host}/cable`
  : undefined

export default createConsumer(wsUrl)
