cmake_minimum_required(VERSION 3.27)
project(BIT_Run C)

set(CMAKE_C_STANDARD 11)


add_executable(BIT_Run
#        resource.h
        cimple/main.c
        cimple/lifecycle.c
        cimple/drawingThread.c
        cimple/spirits.c
)

set(CMAKE_GENERATOR_PLATFORM x86)



install(
        TARGETS BIT_Run
        DESTINATION ${CMAKE_SOURCE_DIR}/cimple
)

target_include_directories(BIT_Run
        PUBLIC
        cimple/include
)
target_link_libraries(BIT_Run
        Msimg32
)

