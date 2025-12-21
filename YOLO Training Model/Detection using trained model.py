import cv2
from  ultralytics import YOLO
model = YOLO('runs/detect/vehicles_detection_YOLO/weights/best.pt')
video1_path = 'Traffic video.mp4'
video2_path = 'Traffic video2.mp4'
while True:
    option = input('Which video would you like to detect?\n1.Traffic video.mp4\n2.Traffic video2.mp4\nchoose:')
    if option == '1':
        cap= cv2.VideoCapture(video1_path)
        break
    elif option == '2':
        cap =cv2.VideoCapture(video2_path)
        break
    else:
        print('Invalid option. Please try again.')


prev_pos ={}
while True:
    _, frame = cap.read()
    objects = model.predict(frame)
    current_pos = {}
    for object in objects:
        for box in object.boxes:
            x1,y1,x2,y2 =map(int, box.xyxy[0])
            center_x = (x1+x2)/2
            center_y = (y1+y2)/2
            current_pos[center_x] = center_y
            cv2.rectangle(frame,(x1,y1),(x2,y2),(0,255,0),2)
            id = int(box.cls[0])
            name = object.names[id]
            #print(f"{id}: {name}")
            cv2.putText(frame, name , (x1,y1+30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

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