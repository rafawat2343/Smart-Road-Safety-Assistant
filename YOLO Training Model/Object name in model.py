import cv2
from ultralytics import YOLO

#model = YOLO('../OpenCV practice/yolov8n.pt')
model = YOLO('runs/detect/vehicles_detection_YOLO/weights/best.pt')
cls = model.names

for id,name in cls.items():
    print(f"{id}: {name}")