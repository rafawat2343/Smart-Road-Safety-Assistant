import cv2
from ultralytics import YOLO
import numpy as np

model = YOLO('runs/detect/vehicles_detection_YOLO/weights/best.pt')

#Tuples of axes for correct direction vector
#(0, 1) = down
#(0, -1) = up
#(1, 0) = right
#(-1, 0) = left
#(1, 1) = diagonal down-right
#(-1, 1) = diagonal down-left
#(1, -1) = diagonal up-right
#(-1, -1) = diagonal up-left

option = input('Which will be your view direction?\n1.incoming\n2.outgoing\nchoose option:')
if option == '1':
    expected_vectors = np.array([[0,1],[1,1],[-1,1]])
else:
    expected_vectors = np.array([[0,-1],[1,-1],[-1,-1]])

movement_threshold = 5

video1_path = 'Traffic video.mp4'
video2_path = 'Traffic video2.mp4'

while True:
    option = input('Which video would you like to detect?\n1. Traffic video.mp4\n2. Traffic video2.mp4\nchoose: ')
    if option == '1':
        cap = cv2.VideoCapture(video1_path)
        break
    elif option == '2':
        cap = cv2.VideoCapture(video2_path)
        break
    else:
        print('Invalid option. Please try again.')

prev_positions = {}

while True:
    ret, frame = cap.read()
    if not ret:
        break

    results = model.track(frame, persist=True, tracker="bytetrack.yaml")

    if not results or results[0].boxes is None:
        continue

    h, w, _ = frame.shape
    start_point = (int(w/2), int(h/2))
    end_point = (int(start_point[0] + expected_vectors[0,0]*100), int(start_point[1] + expected_vectors[0,1]*100))
    cv2.arrowedLine(frame, start_point, end_point, (255, 255, 0), 3)
    cv2.putText(frame, "Expected", (start_point[0]+10, start_point[1]-10),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)

    for box in results[0].boxes:
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        cx, cy = int((x1 + x2) / 2), int((y1 + y2) / 2)
        track_id = int(box.id[0]) if box.id is not None else None
        cls_id = int(box.cls[0])
        name = results[0].names[cls_id]
        if track_id is None:
            continue

        #cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(frame, f"{name}", (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

        if track_id in prev_positions:
            prev_x, prev_y = prev_positions[track_id]
            dx, dy = cx - prev_x, cy - prev_y

            if abs(dx) < movement_threshold and abs(dy) < movement_threshold:
                continue

            isWrong = True
            for expected_vector in expected_vectors:
                dot = dx * expected_vector[0] + dy * expected_vector[1]
                if dot >=0:
                    isWrong = False
                    break

            if isWrong:
                direction_status = "WRONG DIRECTION"
                color = (0, 0, 255)
                cv2.putText(frame, direction_status, (x1, y2 + 25),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

        prev_positions[track_id] = (cx, cy)

    cv2.imshow("Wrong Direction Detection", frame)
    if cv2.waitKey(10)== ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
