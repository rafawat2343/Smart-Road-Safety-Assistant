import cv2
from  ultralytics import YOLO
model = YOLO('yolov8n.pt')
cap = cv2.VideoCapture('Traffic video2.mp4')
prev_pos ={}
while True:
    _, frame = cap.read()
    objects = model.predict(frame)
    current_pos = {}
    for object in objects:
        for box in object.boxes:
            if int(box.cls[0]) == 5:
                x1,y1,x2,y2 =map(int, box.xyxy[0])
                center_x = (x1+x2)/2
                center_y = (y1+y2)/2
                current_pos[center_x] = center_y
                cv2.rectangle(frame,(x1,y1),(x2,y2),(0,255,0),2)
                #cv2.putText(frame, 'bus' , (x1,y1), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

                if center_x in prev_pos:
                    if center_y < prev_pos[center_x]:
                        direction = 'outgoing'
                        color = (255, 0, 0)
                    elif center_y == prev_pos[center_x]:
                        direction = 'not going'
                        color = (0, 0, 255)
                    else:
                        direction = 'incoming'
                        color = (0, 255, 0)
                    cv2.putText(frame, direction, (x1, y1+10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

    prev_pos = current_pos.copy()
    cv2.imshow('Vehicles in video', frame)
    if cv2.waitKey(10) == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()